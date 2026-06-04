-- PantherClaw DB Migration V3: Enhanced CMS Features

-- 1. Add new columns to products
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS fabric_details TEXT,
ADD COLUMN IF NOT EXISTS care_instructions TEXT,
ADD COLUMN IF NOT EXISTS fit_type TEXT;

-- 2. Update Materialized View to include new columns
DROP MATERIALIZED VIEW IF EXISTS public.mv_shop_catalog;

CREATE MATERIALIZED VIEW public.mv_shop_catalog AS
SELECT 
  p.id,
  p.slug,
  p.name,
  p.subtitle,
  p.description,
  p.fabric_details,
  p.care_instructions,
  p.fit_type,
  p.price,
  p.mrp,
  p.images,
  p.badge,
  c.name AS category_name,
  COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', v.id, 
        'sku', v.sku, 
        'size', v.size, 
        'color', v.color,
        'color_hex', v.color_hex,
        'inventory_count', v.inventory_count
      )
    ) FILTER (WHERE v.id IS NOT NULL), '[]'::jsonb
  ) as variants,
  COALESCE(AVG(r.rating), 0) as average_rating,
  COUNT(r.id) as review_count
FROM public.products p
LEFT JOIN public.categories c ON p.category_id = c.id
LEFT JOIN public.product_variants v ON v.product_id = p.id
LEFT JOIN public.reviews r ON r.product_id = p.id
WHERE p.is_active = true
GROUP BY p.id, c.name;

CREATE UNIQUE INDEX idx_mv_shop_catalog_id ON public.mv_shop_catalog(id);
