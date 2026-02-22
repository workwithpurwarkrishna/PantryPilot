create policy "ingredients_insert_by_authenticated"
on public.ingredients
for insert
to authenticated
with check (true);
