-- ==============================================================================
-- COLOR-FIRST MIGRATION SCRIPT
-- Run this in the Supabase SQL Editor
-- WARNING: This alters your product_variants schema.
-- ==============================================================================

-- 1. Create the product_colors table
CREATE TABLE IF NOT EXISTS public.product_colors (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  color_name text NOT NULL,
  color_slug text NOT NULL,
  color_hex text NOT NULL,
  images text[] NOT NULL DEFAULT '{}',
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT product_colors_pkey PRIMARY KEY (id),
  CONSTRAINT uq_product_color_slug UNIQUE (product_id, color_slug)
);

-- 2. Alter product_variants to link to product_colors
-- We drop the flat matrix columns and add the relational foreign key
ALTER TABLE public.product_variants
  DROP COLUMN IF EXISTS color,
  DROP COLUMN IF EXISTS color_hex,
  DROP COLUMN IF EXISTS images,
  ADD COLUMN IF NOT EXISTS color_id uuid REFERENCES public.product_colors(id) ON DELETE CASCADE;

-- 3. Drop the old materialized view and its triggers if they exist
DROP TRIGGER IF EXISTS refresh_catalog_on_product_change ON public.products;
DROP TRIGGER IF EXISTS refresh_catalog_on_variant_change ON public.product_variants;
DROP MATERIALIZED VIEW IF EXISTS public.mv_shop_catalog;

-- 4. Create the new Color-First Materialized View
CREATE MATERIALIZED VIEW public.mv_color_catalog AS
SELECT
  -- Color identity (this IS the catalog card)
  pc.id           AS color_id,
  pc.color_slug,
  pc.color_name,
  pc.color_hex,
  pc.images,                    
  pc.sort_order,

  -- Parent product info
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

  -- Sizes available for THIS specific color only
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'variant_id',      pv.id,
        'sku',             pv.sku,
        'size',            pv.size,
        'inventory_count', pv.inventory_count,
        'in_stock',        (pv.inventory_count > 0)
      )
      ORDER BY
        CASE pv.size
          WHEN 'XS'  THEN 1
          WHEN 'S'   THEN 2
          WHEN 'M'   THEN 3
          WHEN 'L'   THEN 4
          WHEN 'XL'  THEN 5
          WHEN 'XXL' THEN 6
          ELSE 99
        END
    ) FILTER (WHERE pv.id IS NOT NULL),
    '[]'::jsonb
  ) AS sizes,

  -- ALL sibling colors for the same product
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

  -- Review stats
  COALESCE(ROUND(AVG(r.rating)::NUMERIC, 1), 0) AS average_rating,
  COUNT(DISTINCT r.id)                           AS review_count,

  -- Quick stock flag for the catalog card
  EXISTS (
    SELECT 1 FROM public.product_variants pv2
    WHERE pv2.color_id = pc.id
      AND pv2.inventory_count > 0
  ) AS has_stock

FROM public.product_colors  pc
JOIN public.products         p  ON p.id  = pc.product_id
LEFT JOIN public.categories  c  ON c.id  = p.category_id
LEFT JOIN public.product_variants pv ON pv.color_id = pc.id
LEFT JOIN public.reviews          r  ON r.product_id = p.id
WHERE p.is_active  = true
  AND pc.is_active = true
GROUP BY
  pc.id, p.id, c.id;

-- 5. Create Indices for Performance
CREATE UNIQUE INDEX idx_mv_color_catalog_color_id
  ON public.mv_color_catalog(color_id);

CREATE UNIQUE INDEX idx_mv_color_catalog_slugs
  ON public.mv_color_catalog(product_slug, color_slug);

CREATE INDEX idx_mv_color_catalog_category
  ON public.mv_color_catalog(category_slug);

CREATE INDEX idx_mv_color_catalog_stock
  ON public.mv_color_catalog(has_stock);

-- 6. Setup Triggers to Refresh View
CREATE OR REPLACE FUNCTION refresh_mv_color_catalog()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_color_catalog;
  RETURN NULL;
END;
$$;

CREATE TRIGGER refresh_on_product_change
  AFTER INSERT OR UPDATE OR DELETE ON public.products
  FOR EACH STATEMENT EXECUTE FUNCTION refresh_mv_color_catalog();

CREATE TRIGGER refresh_on_color_change
  AFTER INSERT OR UPDATE OR DELETE ON public.product_colors
  FOR EACH STATEMENT EXECUTE FUNCTION refresh_mv_color_catalog();

CREATE TRIGGER refresh_on_variant_change
  AFTER INSERT OR UPDATE OR DELETE ON public.product_variants
  FOR EACH STATEMENT EXECUTE FUNCTION refresh_mv_color_catalog();
