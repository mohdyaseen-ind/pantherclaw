-- ==============================================================================
-- UNIFIED INVENTORY & SIZES MIGRATION
-- Run this in the Supabase SQL Editor
-- WARNING: Wipe dummy data in product_variants before running to avoid FK issues.
-- ==============================================================================

-- 1. Create sizes table
CREATE TABLE IF NOT EXISTS public.sizes (
  id         UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  label      TEXT    NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL,
  is_active  BOOLEAN DEFAULT true
);

-- Insert predefined sizes (if not exists)
INSERT INTO public.sizes (label, sort_order) 
VALUES
  ('XS',  1),
  ('S',   2),
  ('M',   3),
  ('L',   4),
  ('XL',  5),
  ('XXL', 6)
ON CONFLICT (label) DO NOTHING;

-- 2. Alter product_variants to reference sizes
ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS size_id UUID REFERENCES public.sizes(id);

-- Backfill existing variants if there are any
UPDATE public.product_variants pv
SET size_id = s.id
FROM public.sizes s
WHERE s.label = pv.size
AND pv.size_id IS NULL;

-- Make size_id NOT NULL if you are sure data is clean.
-- Leaving nullable here to prevent immediate crash if dummy data exists, 
-- but you should manually clear and set NOT NULL later.

-- Unique constraint: one row per color + size
ALTER TABLE public.product_variants DROP CONSTRAINT IF EXISTS uq_color_size;
ALTER TABLE public.product_variants ADD CONSTRAINT uq_color_size UNIQUE (color_id, size_id);

-- 3. Inventory Logs Table
CREATE TABLE IF NOT EXISTS public.inventory_logs (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  variant_id    UUID        NOT NULL REFERENCES public.product_variants(id) ON DELETE CASCADE,
  change_type   TEXT        NOT NULL CHECK (change_type IN (
                              'restock',      -- supplier delivery
                              'sale',         -- customer bought it
                              'return',       -- customer returned it
                              'adjustment',   -- manual correction
                              'damage'        -- item damaged/lost
                            )),
  quantity_delta INTEGER    NOT NULL,
  quantity_before INTEGER  NOT NULL,
  quantity_after  INTEGER  NOT NULL,
  note          TEXT,
  performed_by  UUID        REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_inv_log_variant   ON public.inventory_logs(variant_id);
CREATE INDEX IF NOT EXISTS idx_inv_log_created   ON public.inventory_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_log_type      ON public.inventory_logs(change_type);

-- 4. Update Inventory Function (Safe RPC)
CREATE OR REPLACE FUNCTION update_inventory(
  p_variant_id   UUID,
  p_change_type  TEXT,
  p_quantity     INTEGER,
  p_note         TEXT DEFAULT NULL,
  p_performed_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_before  INTEGER;
  v_after   INTEGER;
  v_delta   INTEGER;
  v_result  JSONB;
BEGIN
  -- Lock this specific row so concurrent restocks don't race
  SELECT inventory_count INTO v_before
  FROM public.product_variants
  WHERE id = p_variant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Variant % not found', p_variant_id;
  END IF;

  -- Determine Delta
  IF p_change_type IN ('sale', 'damage') THEN
    v_delta := -ABS(p_quantity);
  ELSIF p_change_type = 'adjustment' THEN
    v_delta := p_quantity; -- adjustments can be negative or positive
  ELSE
    v_delta := ABS(p_quantity);
  END IF;

  v_after := v_before + v_delta;

  -- Hard stop — stock can never go below 0
  IF v_after < 0 THEN
    RAISE EXCEPTION 'Cannot reduce stock below 0. Current: %, Requested Change: %',
      v_before, v_delta;
  END IF;

  -- Apply the change
  UPDATE public.product_variants
  SET inventory_count = v_after,
      updated_at      = timezone('utc', now())
  WHERE id = p_variant_id;

  -- Write the log entry
  INSERT INTO public.inventory_logs (
    variant_id, change_type, quantity_delta,
    quantity_before, quantity_after, note, performed_by
  )
  VALUES (
    p_variant_id, p_change_type, v_delta,
    v_before, v_after, p_note, p_performed_by
  );

  -- Return the result
  v_result := jsonb_build_object(
    'variant_id',  p_variant_id,
    'before',      v_before,
    'after',       v_after,
    'delta',       v_delta,
    'change_type', p_change_type
  );

  RETURN v_result;
END;
$$;

-- 5. Auto-Create Triggers
-- When Color is inserted
CREATE OR REPLACE FUNCTION auto_create_variants_for_new_color()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.product_variants (
    product_id, color_id, size_id, size, sku, inventory_count
  )
  SELECT
    NEW.product_id,
    NEW.id,
    s.id,
    s.label,
    LOWER(
      (SELECT slug FROM public.products WHERE id = NEW.product_id)
      || '-' || NEW.color_slug
      || '-' || s.label
    ),
    0
  FROM public.sizes s
  WHERE s.is_active = true;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_color_insert_create_variants ON public.product_colors;
CREATE TRIGGER on_color_insert_create_variants
  AFTER INSERT ON public.product_colors
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_variants_for_new_color();

-- When new global Size is inserted
CREATE OR REPLACE FUNCTION auto_create_variants_for_new_size()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.product_variants (
    product_id, color_id, size_id, size, sku, inventory_count
  )
  SELECT
    pc.product_id,
    pc.id,
    NEW.id,
    NEW.label,
    LOWER(
      (SELECT slug FROM public.products WHERE id = pc.product_id)
      || '-' || pc.color_slug
      || '-' || NEW.label
    ),
    0
  FROM public.product_colors pc
  WHERE pc.is_active = true;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_size_insert_create_variants ON public.sizes;
CREATE TRIGGER on_size_insert_create_variants
  AFTER INSERT ON public.sizes
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_variants_for_new_size();

-- 6. Update process_checkout (we overwrite the full function if it exists)
-- Assuming the basic structure of process_checkout from standard spec
CREATE OR REPLACE FUNCTION process_checkout(p_user_id UUID, p_session_id UUID, p_address_id UUID, p_discount_code TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_order_id UUID;
  v_total_amount INTEGER := 0;
  v_item RECORD;
BEGIN
  -- Create order
  INSERT INTO public.orders (user_id, address_id, status)
  VALUES (p_user_id, p_address_id, 'pending')
  RETURNING id INTO v_order_id;

  -- Loop through cart items
  FOR v_item IN (SELECT c.variant_id, c.quantity, pv.product_id, p.price FROM public.cart_items c JOIN public.product_variants pv ON c.variant_id = pv.id JOIN public.products p ON p.id = pv.product_id WHERE c.session_id = p_session_id) LOOP
    
    -- THIS IS THE NEW SAFE UPDATE LOGIC
    PERFORM update_inventory(
      v_item.variant_id,
      'sale',
      v_item.quantity,
      'Order ' || v_order_id::TEXT,
      p_user_id
    );

    -- Insert order item
    INSERT INTO public.order_items (order_id, variant_id, quantity, price_at_purchase)
    VALUES (v_order_id, v_item.variant_id, v_item.quantity, v_item.price);

    v_total_amount := v_total_amount + (v_item.quantity * v_item.price);
  END LOOP;

  -- Update order total
  UPDATE public.orders SET total_amount = v_total_amount WHERE id = v_order_id;

  -- Clear cart
  DELETE FROM public.cart_items WHERE session_id = p_session_id;

  RETURN v_order_id;
END;
$$;

-- 7. Recreate mv_color_catalog to use sizes table for guaranteed ordering
DROP MATERIALIZED VIEW IF EXISTS public.mv_color_catalog;

CREATE MATERIALIZED VIEW public.mv_color_catalog AS
SELECT
  pc.id           AS color_id,
  pc.color_slug,
  pc.color_name,
  pc.color_hex,
  pc.images,
  pc.sort_order,
  p.id            AS product_id,
  p.slug          AS product_slug,
  p.name          AS product_name,
  p.subtitle,
  p.price,
  p.mrp,
  p.badge,
  p.fit_type,
  p.description,
  p.fabric_details,
  p.care_instructions,
  c.name          AS category_name,
  c.slug          AS category_slug,

  -- Sizes array guaranteed to have all 6
  jsonb_agg(
    jsonb_build_object(
      'variant_id',      pv.id,
      'sku',             pv.sku,
      'size',            s.label,
      'sort_order',      s.sort_order,
      'inventory_count', pv.inventory_count,
      'in_stock',        (pv.inventory_count > 0)
    )
    ORDER BY s.sort_order
  ) AS sizes,

  -- Sibling colors
  (
    SELECT jsonb_agg(
      jsonb_build_object(
        'color_id',   pc2.id,
        'color_name', pc2.color_name,
        'color_hex',  pc2.color_hex,
        'color_slug', pc2.color_slug,
        'thumbnail',  pc2.images[1]
      )
      ORDER BY pc2.sort_order
    )
    FROM public.product_colors pc2
    WHERE pc2.product_id = pc.product_id
      AND pc2.is_active  = true
  ) AS all_colors,

  COALESCE(ROUND(AVG(r.rating)::NUMERIC, 1), 0) AS average_rating,
  COUNT(DISTINCT r.id)                           AS review_count,

  EXISTS (
    SELECT 1 FROM public.product_variants pv2
    WHERE pv2.color_id = pc.id
      AND pv2.inventory_count > 0
  ) AS has_stock

FROM public.product_colors   pc
JOIN public.products          p  ON p.id       = pc.product_id
JOIN public.product_variants  pv ON pv.color_id = pc.id
JOIN public.sizes             s  ON s.id        = pv.size_id
LEFT JOIN public.categories   c  ON c.id        = p.category_id
LEFT JOIN public.reviews      r  ON r.product_id = p.id
WHERE p.is_active  = true
  AND pc.is_active = true
  AND s.is_active  = true
GROUP BY pc.id, p.id, c.id;

CREATE UNIQUE INDEX idx_mv_color_catalog_color_id ON public.mv_color_catalog(color_id);
CREATE UNIQUE INDEX idx_mv_color_catalog_slugs ON public.mv_color_catalog(product_slug, color_slug);
CREATE INDEX idx_mv_color_catalog_category ON public.mv_color_catalog(category_slug);
CREATE INDEX idx_mv_color_catalog_stock ON public.mv_color_catalog(has_stock);

-- We need to ensure the refresh triggers stay intact
CREATE OR REPLACE FUNCTION refresh_mv_color_catalog()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_color_catalog;
  RETURN NULL;
END;
$$;
-- (Assuming triggers from previous migration are still active)
