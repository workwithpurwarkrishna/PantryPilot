update public.ingredients
set category = 'Grains & Cereals'
where category in ('Grains', 'grains', 'grain');

update public.ingredients
set category = 'Proteins'
where category in ('Protein', 'protein', 'proteins');

alter table public.ingredients
drop constraint if exists ingredients_category_allowed_check;

alter table public.ingredients
add constraint ingredients_category_allowed_check
check (
  category in (
    'Vegetables',
    'Fruits',
    'Grains & Cereals',
    'Dairy',
    'Proteins',
    'Spices & Seasonings',
    'Oils',
    'Sauces',
    'Others'
  )
);
