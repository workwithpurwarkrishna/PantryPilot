insert into public.ingredients (name, category, default_unit)
values
  ('Basmati Rice', 'Grains', 'kg'),
  ('Tomato', 'Vegetables', 'pcs'),
  ('Onion', 'Vegetables', 'pcs'),
  ('Paneer', 'Dairy', 'g'),
  ('Egg', 'Protein', 'pcs'),
  ('Milk', 'Dairy', 'ml'),
  ('Potato', 'Vegetables', 'pcs')
on conflict (name) do nothing;
