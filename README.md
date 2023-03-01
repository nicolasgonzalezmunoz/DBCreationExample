# DBCreationExample
This is an example that's intended to show the skills of the author. At the moment, this repositories contains only one file, which purpose is to create a database with its tables, some triggers to enforce some business rules, insert some example data and create a view which resumes some of the most important aspects of the business, all using MySQL.

In this case, let's imagine that we have a small business that sales some technological products. Our database is named 'sales', with the tables 'brand', 'product', 'worker' 'sale' and 'event_history'. The table 'product' also manages a column with JSON files. Each table contains the following information:

- 'brand' contains the name of the brands the business works with.
- 'product' contains the product name, the brand of the product (as the id of the said brand), the attributes of the product (as a JSON object), the actual price of the product and amount in the inventory.
- 'worker' contains info about the workers of the company, as their document number, worker name, email (if given) and the job they do.
- 'sale' contains info about the product ID, the seller ID, the quantity sold and the date the sale was made.
- 'event_history' is an informative table that points each modification made to the database and the date the modification happened.

In any case, the script creates some triggers that enforce the following rules:
1. A given brand can't be multiple times in the table 'brand'.
2. A worker has a unique document number. Also, there can't be two workers with the same email.
3. A worker's document number can't be changed, except if the entry is deleted and then inserted again.
4. When a product is inserted into the table 'product', it has to be a brand ID that already exists in the table 'brand'. Also, the inventory can't be negative.
5. A sale can only be executed if the worker has the job 'seller' or 'manager'. Any sale attempt made by a worker with any other job should be denied.
6. When a sale is made, the quantity sold has to be substracted from the inventory of the respective product. If the quantity sold is greater than the available inventory, the sale should be denied.
7. 'event_history' has to be automatically updated when a change in any other table on the database occurs.

Also, the script includes the creation of a procedure that inserts random data on the 'sale' table (which insertion could be denied if the random value given for seller_id does not satisfies rule 5). Additionally, a view is created at the end of the script that contains info about product name, brand id, price, quantity sold and sale date.
