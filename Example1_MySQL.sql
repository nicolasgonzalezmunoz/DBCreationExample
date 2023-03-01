/*
This code is only for demonsration purposes, just to show what the programmer can do.
In this case, we imagine that we are working with a database for a small business,
starting the database from zero. This script create the database, the necesary tables
and then create some triggers to manage some business rules, like to indicate
when inventory fell below 0.
Finally, we insert some data to test that all is behaving as intended.
*/

-- Create and select database
CREATE DATABASE sales;
USE sales;

-- Create table of the database
CREATE TABLE brand(
    id INT NOT NULL AUTO_INCREMENT,
    brand_name VARCHAR(20) NOT NULL,
    PRIMARY KEY(id)
);

CREATE UNIQUE INDEX brand_unique
On brand (brand_name);

CREATE TABLE product(
    id INT NOT NULL AUTO_INCREMENT,
    product_name VARCHAR(50) NOT NULL,
    brand_id INT NOT NULL,
    attribute JSON NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    inventory INT NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(brand_id) REFERENCES brand(id)
);

CREATE INDEX prod_name
ON product(product_name);

CREATE TABLE worker(
    id INT NOT NULL AUTO_INCREMENT,
    document_number VARCHAR(16) NOT NULL,
    worker_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) DEFAULT NULL,
    job VARCHAR(50) NOT NULL,
    PRIMARY KEY(id)
);

CREATE UNIQUE INDEX doc_number
ON worker(document_number);

CREATE INDEX worker_index
ON worker(worker_name);

CREATE TABLE sale(
    id INT NOT NULL AUTO_INCREMENT,
    product_id INT NOT NULL,
    seller_id INT NOT NULL,
    quantity INT NOT NULL,
    sale_datetime DATETIME NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY(seller_id) REFERENCES worker(id),
    FOREIGN KEY(product_id) REFERENCES product(id)
);

CREATE INDEX sale_date
ON sale(sale_datetime);

CREATE TABLE event_history(
    id INT NOT NULL AUTO_INCREMENT,
    eve VARCHAR(100) NOT NULL,
    event_datetime DATETIME NOT NULL,
    PRIMARY KEY(id)
);

-- Create some triggers

-- Verifies if the inserted brand is already in the database. If it is, then prevent the insertion.
DELIMITER //
CREATE TRIGGER before_brand_insert BEFORE INSERT ON brand
FOR EACH ROW
BEGIN
    SET @check = (SELECT COUNT(*) FROM brand WHERE brand_name = NEW.brand_name);
    IF @check = 0 THEN
        INSERT INTO event_history(eve, event_datetime) VALUES ('New brand inserted.', CURRENT_TIMESTAMP());
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Brand already exists.';
    END IF;
END//

-- Verifies if the modification in brand is valid
CREATE TRIGGER before_brand_update BEFORE UPDATE ON brand
FOR EACH ROW
BEGIN
    SET @check = (SELECT COUNT(*) FROM brand WHERE brand_name = NEW.brand_name);
    IF @check = 0 THEN
        INSERT INTO event_history(eve, event_datetime) VALUES ('Brand entry modified.', CURRENT_TIMESTAMP);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Brand already exists.';
    END IF;
END//

-- Verifies if the product already exists, if the inventory is inicialized as nonnegative
-- and if the brand of the product is already initialized
CREATE TRIGGER before_product_insert BEFORE INSERT ON product
FOR EACH ROW
BEGIN
    SET @emptycheck = (SELECT EXISTS (SELECT 1 FROM brand));-- Check if brand table is empty
    IF @emptycheck = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Please first insert a brand name in brand table.';
    ELSE
        SET @brand_check = (SELECT COUNT(*) FROM brand WHERE id = NEW.brand_id);
    END IF;
    SET @emptycheck = (SELECT EXISTS (SELECT 1 FROM product));-- Check if product table is empty
    IF @emptycheck = 0 THEN
        SET @unique_check = 0;
    ELSE
        SET @unique_check = (SELECT COUNT(*) FROM product WHERE product_name = NEW.product_name AND brand_id = NEW.brand_id);
    END IF;
    IF @unique_check = 0 AND @brand_check > 0 AND NEW.inventory >=0 THEN
        INSERT INTO event_history(eve, event_datetime) VALUES ("New product inserted.", CURRENT_TIMESTAMP);
    ELSEIF @unique_check > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product is already in database.';
    ELSEIF NEW.inventory < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory has to be inicialized as 0 or a positive number.';
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Brand ID is not registered in database. Please insert the brand name in the respective table.';
    END IF;
END//

-- Verifies if the modification on product is valid, i.e, if the inventory is nonnegative and 
-- if the brand exists in the respective table
CREATE TRIGGER before_product_update BEFORE UPDATE ON product
FOR EACH ROW
BEGIN
    SET @brandcheck = (SELECT COUNT(*) FROM brand WHERE id = NEW.brand_id);
    IF NEW.inventory >= 0 AND @brandcheck > 0 THEN
        INSERT INTO event_history(eve, event_datetime) VALUES ("Product entry updated.", CURRENT_TIMESTAMP);
    ELSEIF NEW.inventory < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory cannot be negative.';
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The brand for this product does not exist. Please insert the new brand in the brand table.';
    END IF;
END//

-- Verifies if the worker entry already exists (document number is unique for each person)
CREATE TRIGGER before_worker_insert BEFORE INSERT ON worker
FOR EACH ROW
BEGIN
    SET @idcheck = (SELECT COUNT(*) FROM worker WHERE document_number = NEW.document_number);
    SET @emailcheck = (SELECT COUNT(*) FROM worker WHERE email = NEW.email);
    IF @idcheck = 0 AND @emailcheck = 0 THEN
        INSERT INTO event_history(eve, event_datetime) VALUES ("New worker inserted", CURRENT_TIMESTAMP);
    ELSEIF @emailcheck > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Other worker already have the same email.';
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A worker with the same document number already exists.';
    END IF;
END//

-- Prevents the modification of the worker's document number.
-- Also verifies that a email change doesn't overlaps with other worker's email (email is unique)
CREATE TRIGGER before_worker_update BEFORE UPDATE ON worker
FOR EACH ROW
BEGIN
    IF NEW.email IS NOT NULL THEN
        SET @mailcheck = (SELECT COUNT(*) FROM worker WHERE email = NEW.email);
        IF NEW.document_number = OLD.document_number AND @mailcheck = 0 THEN
            INSERT INTO event_history(eve, event_datetime) VALUES ("Worker entry updated", CURRENT_TIMESTAMP);
        ELSEIF @mailcheck > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'There already exists a worker with the same email.';
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The document number cannot be changed.';
        END IF;
    ELSE
        IF NEW.document_number = OLD.document_number THEN
            INSERT INTO event_history(eve, event_datetime) VALUES ("Worker entry updated", CURRENT_TIMESTAMP);
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The document number cannot be changed.';
        END IF;
    END IF;
END//

-- Verifies if the sale quantity is not greater than the available inventory and if sale
-- is made by authorized personal (a seller or a manager)
CREATE TRIGGER before_sale_insert BEFORE INSERT ON sale
FOR EACH ROW
BEGIN
    SET @emptycheck = (SELECT EXISTS (SELECT 1 FROM worker));
    IF @emptycheck = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'worker table is empty. Please, update it before doing any sales.';
    END IF;
    SET @job = (SELECT job FROM worker WHERE id = NEW.seller_id);
    IF @job = 'seller' OR @job = 'manager' THEN
        SET @sellercheck = 1;
    ELSE
        SET @sellercheck = 0;
    END IF;
    IF (NEW.quantity > (SELECT inventory FROM product WHERE id = NEW.product_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory not enough to satisfy sale quantity.';
    ELSEIF @sellercheck = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The worker is not authorized to do this task.';
    ELSE
        INSERT INTO event_history(eve, event_datetime) VALUES ("Sale succesfull.",CURRENT_TIMESTAMP);
        UPDATE product SET inventory = inventory - NEW.quantity WHERE id = NEW.product_id;
    END IF;
END//

-- After a sale is canceled, it replenish the inventory by the amount of the sale deleted
CREATE TRIGGER after_sale_delete AFTER DELETE ON sale
FOR EACH ROW
BEGIN
    UPDATE product SET inventory = inventory + OLD.quantity WHERE id = OLD.product_id;
    INSERT INTO event_history(eve, event_datetime) VALUES ("Sale canceled.", CURRENT_TIMESTAMP);
END//
DELIMITER ;

-- Insert values on tables and see what happens
INSERT INTO brand (brand_name) VALUES
('apple'),
('samsung'),
('canon');

INSERT INTO product (product_name, brand_id, attribute, price, inventory) VALUES
('iphone', 
1, 
JSON_OBJECT('network', JSON_ARRAY('3g','4g','5g'), 'size', '20 inch', 'resolution', '600 px'),
700,
45),
('macbook',
1,
JSON_OBJECT('processor', '3.5Hz', 'OS', 'macOS', 'RAM', '16GB', 'size', '25 inch'),
1200,
15),
('galaxy 21S',
2,
JSON_OBJECT('network', JSON_ARRAY('3g', '4g'), 'size', '21 inch', 'resolution', '600 px'),
650,
70),
('camera',
3,
JSON_OBJECT('resolution', '48Mpx', 'zoom', '5.0x', 'extra lenses', JSON_ARRAY('fish-eye', 'panomaric')),
500,
120);

INSERT INTO worker (document_number, worker_name, email, job) VALUES
('15362051-k', 'Patricio Gonzalez', 'eric.gonzalez@gmail.com','seller'),
('20012035-0', 'JSON Perez', 'programmer@gmail.com', 'programmer'),
('7022113-6', 'Marcelo Munoz', 'mm@gmail.cl', 'janitor'),
('13765012-9', 'Hernesto Martinez', 'hermar@gmail.cl', 'seller'),
('10285222-2', 'Jhon Wright', 'jw@outlook.com', 'manager');

-- Create a procedure to insert random data into the sale table
DELIMITER //
CREATE PROCEDURE sale_insert_random_routine(IN ninsert INT)
BEGIN
    SET @start = 0;
    WHILE @start < ninsert DO
        INSERT INTO sale (product_id, seller_id, quantity, sale_datetime) VALUES
        ((SELECT FLOOR(RAND()*4)+1), (SELECT FLOOR(RAND()*5)+1), (SELECT FLOOR(RAND()*10)+1), CURRENT_TIMESTAMP); -- Insert random, integer values
        SET @start = @start + 1;
    END WHILE;
END//

DELIMITER ;
CALL sale_insert_random_routine(1);

-- Create a view with the most important info on products and sales
CREATE VIEW sale_per_product AS 
SELECT p.product_name, p.brand_id, p.price, s.quantity, s.sale_datetime FROM sale s RIGHT JOIN product p ON s.product_id = p.id;