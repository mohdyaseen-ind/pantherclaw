-- Insert top-level categories (Departments) and capture their IDs
WITH inserted_parents AS (
  INSERT INTO public.categories (name, slug)
  VALUES 
    ('Men', 'men'),
    ('Women', 'women')
  ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
  RETURNING id, slug
)
-- Insert subcategories using the captured parent IDs
INSERT INTO public.categories (name, slug, parent_id)
VALUES 
  ('Jeans', 'men-jeans', (SELECT id FROM inserted_parents WHERE slug = 'men')),
  ('Jeans', 'women-jeans', (SELECT id FROM inserted_parents WHERE slug = 'women')),
  ('Crop Tops', 'women-crop-tops', (SELECT id FROM inserted_parents WHERE slug = 'women'))
ON CONFLICT (slug) DO NOTHING;
