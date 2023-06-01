PGDMP     7    %            	    z         	   dvdrental    14.1    14.1 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    24583 	   dvdrental    DATABASE     T   CREATE DATABASE dvdrental WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'C';
    DROP DATABASE dvdrental;
                postgres    false            a           1247    24585    mpaa_rating    TYPE     a   CREATE TYPE public.mpaa_rating AS ENUM (
    'G',
    'PG',
    'PG-13',
    'R',
    'NC-17'
);
    DROP TYPE public.mpaa_rating;
       public          postgres    false            d           1247    24596    year    DOMAIN     k   CREATE DOMAIN public.year AS integer
	CONSTRAINT year_check CHECK (((VALUE >= 1901) AND (VALUE <= 2155)));
    DROP DOMAIN public.year;
       public          postgres    false            �            1255    24598    _group_concat(text, text)    FUNCTION     �   CREATE FUNCTION public._group_concat(text, text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT CASE
  WHEN $2 IS NULL THEN $1
  WHEN $1 IS NULL THEN $2
  ELSE $1 || ', ' || $2
END
$_$;
 0   DROP FUNCTION public._group_concat(text, text);
       public          postgres    false            �            1255    24599    film_in_stock(integer, integer)    FUNCTION     $  CREATE FUNCTION public.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
     SELECT inventory_id
     FROM inventory
     WHERE film_id = $1
     AND store_id = $2
     AND inventory_in_stock(inventory_id);
$_$;
 e   DROP FUNCTION public.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer);
       public          postgres    false            �            1255    24600 #   film_not_in_stock(integer, integer)    FUNCTION     '  CREATE FUNCTION public.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
    SELECT inventory_id
    FROM inventory
    WHERE film_id = $1
    AND store_id = $2
    AND NOT inventory_in_stock(inventory_id);
$_$;
 i   DROP FUNCTION public.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer);
       public          postgres    false                       1255    24601 :   get_customer_balance(integer, timestamp without time zone)    FUNCTION       CREATE FUNCTION public.get_customer_balance(p_customer_id integer, p_effective_date timestamp without time zone) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
       --#OK, WE NEED TO CALCULATE THE CURRENT BALANCE GIVEN A CUSTOMER_ID AND A DATE
       --#THAT WE WANT THE BALANCE TO BE EFFECTIVE FOR. THE BALANCE IS:
       --#   1) RENTAL FEES FOR ALL PREVIOUS RENTALS
       --#   2) ONE DOLLAR FOR EVERY DAY THE PREVIOUS RENTALS ARE OVERDUE
       --#   3) IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST
       --#   4) SUBTRACT ALL PAYMENTS MADE BEFORE THE DATE SPECIFIED
DECLARE
    v_rentfees DECIMAL(5,2); --#FEES PAID TO RENT THE VIDEOS INITIALLY
    v_overfees INTEGER;      --#LATE FEES FOR PRIOR RENTALS
    v_payments DECIMAL(5,2); --#SUM OF PAYMENTS MADE PREVIOUSLY
BEGIN
    SELECT COALESCE(SUM(film.rental_rate),0) INTO v_rentfees
    FROM film, inventory, rental
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(IF((rental.return_date - rental.rental_date) > (film.rental_duration * '1 day'::interval),
        ((rental.return_date - rental.rental_date) - (film.rental_duration * '1 day'::interval)),0)),0) INTO v_overfees
    FROM rental, inventory, film
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(payment.amount),0) INTO v_payments
    FROM payment
    WHERE payment.payment_date <= p_effective_date
    AND payment.customer_id = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
END
$$;
 p   DROP FUNCTION public.get_customer_balance(p_customer_id integer, p_effective_date timestamp without time zone);
       public          postgres    false                       1255    24602 #   inventory_held_by_customer(integer)    FUNCTION     ;  CREATE FUNCTION public.inventory_held_by_customer(p_inventory_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_customer_id INTEGER;
BEGIN

  SELECT customer_id INTO v_customer_id
  FROM rental
  WHERE return_date IS NULL
  AND inventory_id = p_inventory_id;

  RETURN v_customer_id;
END $$;
 I   DROP FUNCTION public.inventory_held_by_customer(p_inventory_id integer);
       public          postgres    false                       1255    24603    inventory_in_stock(integer)    FUNCTION     �  CREATE FUNCTION public.inventory_in_stock(p_inventory_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rentals INTEGER;
    v_out     INTEGER;
BEGIN
    -- AN ITEM IS IN-STOCK IF THERE ARE EITHER NO ROWS IN THE rental TABLE
    -- FOR THE ITEM OR ALL ROWS HAVE return_date POPULATED

    SELECT count(*) INTO v_rentals
    FROM rental
    WHERE inventory_id = p_inventory_id;

    IF v_rentals = 0 THEN
      RETURN TRUE;
    END IF;

    SELECT COUNT(rental_id) INTO v_out
    FROM inventory LEFT JOIN rental USING(inventory_id)
    WHERE inventory.inventory_id = p_inventory_id
    AND rental.return_date IS NULL;

    IF v_out > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
END $$;
 A   DROP FUNCTION public.inventory_in_stock(p_inventory_id integer);
       public          postgres    false                       1255    24604 %   last_day(timestamp without time zone)    FUNCTION     �  CREATE FUNCTION public.last_day(timestamp without time zone) RETURNS date
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN EXTRACT(MONTH FROM $1) = 12 THEN
      (((EXTRACT(YEAR FROM $1) + 1) operator(pg_catalog.||) '-01-01')::date - INTERVAL '1 day')::date
    ELSE
      ((EXTRACT(YEAR FROM $1) operator(pg_catalog.||) '-' operator(pg_catalog.||) (EXTRACT(MONTH FROM $1) + 1) operator(pg_catalog.||) '-01')::date - INTERVAL '1 day')::date
    END
$_$;
 <   DROP FUNCTION public.last_day(timestamp without time zone);
       public          postgres    false                       1255    24605    last_updated()    FUNCTION     �   CREATE FUNCTION public.last_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.last_update = CURRENT_TIMESTAMP;
    RETURN NEW;
END $$;
 %   DROP FUNCTION public.last_updated();
       public          postgres    false            �            1259    24606    customer_customer_id_seq    SEQUENCE     �   CREATE SEQUENCE public.customer_customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.customer_customer_id_seq;
       public          postgres    false            �            1259    24607    customer    TABLE     �  CREATE TABLE public.customer (
    customer_id integer DEFAULT nextval('public.customer_customer_id_seq'::regclass) NOT NULL,
    store_id smallint NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    email character varying(50),
    address_id smallint NOT NULL,
    activebool boolean DEFAULT true NOT NULL,
    create_date date DEFAULT ('now'::text)::date NOT NULL,
    last_update timestamp without time zone DEFAULT now(),
    active integer
);
    DROP TABLE public.customer;
       public         heap    postgres    false    209                       1255    24614     rewards_report(integer, numeric)    FUNCTION     4  CREATE FUNCTION public.rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric) RETURNS SETOF public.customer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
rr RECORD;
tmpSQL TEXT;
BEGIN

    /* Some sanity checks... */
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
    END IF;

    last_month_start := CURRENT_DATE - '3 month'::interval;
    last_month_start := to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),'YYYY-MM-DD');
    last_month_end := LAST_DAY(last_month_start);

    /*
    Create a temporary storage area for Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer (customer_id INTEGER NOT NULL PRIMARY KEY);

    /*
    Find all customers meeting the monthly purchase requirements
    */

    tmpSQL := 'INSERT INTO tmpCustomer (customer_id)
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN '||quote_literal(last_month_start) ||' AND '|| quote_literal(last_month_end) || '
        GROUP BY customer_id
        HAVING SUM(p.amount) > '|| min_dollar_amount_purchased || '
        AND COUNT(customer_id) > ' ||min_monthly_purchases ;

    EXECUTE tmpSQL;

    /*
    Output ALL customer information of matching rewardees.
    Customize output as needed.
    */
    FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customer AS c ON t.customer_id = c.customer_id' LOOP
        RETURN NEXT rr;
    END LOOP;

    /* Clean up */
    tmpSQL := 'DROP TABLE tmpCustomer';
    EXECUTE tmpSQL;

RETURN;
END
$_$;
 i   DROP FUNCTION public.rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric);
       public          postgres    false    210            �           1255    24615    group_concat(text) 	   AGGREGATE     c   CREATE AGGREGATE public.group_concat(text) (
    SFUNC = public._group_concat,
    STYPE = text
);
 *   DROP AGGREGATE public.group_concat(text);
       public          postgres    false    244            �            1259    24616    actor_actor_id_seq    SEQUENCE     {   CREATE SEQUENCE public.actor_actor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.actor_actor_id_seq;
       public          postgres    false            �            1259    24617    actor    TABLE       CREATE TABLE public.actor (
    actor_id integer DEFAULT nextval('public.actor_actor_id_seq'::regclass) NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.actor;
       public         heap    postgres    false    211            �            1259    24622    category_category_id_seq    SEQUENCE     �   CREATE SEQUENCE public.category_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.category_category_id_seq;
       public          postgres    false            �            1259    24623    category    TABLE     �   CREATE TABLE public.category (
    category_id integer DEFAULT nextval('public.category_category_id_seq'::regclass) NOT NULL,
    name character varying(25) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.category;
       public         heap    postgres    false    213            �            1259    24628    film_film_id_seq    SEQUENCE     y   CREATE SEQUENCE public.film_film_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.film_film_id_seq;
       public          postgres    false            �            1259    24629    film    TABLE     f  CREATE TABLE public.film (
    film_id integer DEFAULT nextval('public.film_film_id_seq'::regclass) NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    release_year public.year,
    language_id smallint NOT NULL,
    rental_duration smallint DEFAULT 3 NOT NULL,
    rental_rate numeric(4,2) DEFAULT 4.99 NOT NULL,
    length smallint,
    replacement_cost numeric(5,2) DEFAULT 19.99 NOT NULL,
    rating public.mpaa_rating DEFAULT 'G'::public.mpaa_rating,
    last_update timestamp without time zone DEFAULT now() NOT NULL,
    special_features text[],
    fulltext tsvector NOT NULL
);
    DROP TABLE public.film;
       public         heap    postgres    false    215    865    868    865            �            1259    24640 
   film_actor    TABLE     �   CREATE TABLE public.film_actor (
    actor_id smallint NOT NULL,
    film_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.film_actor;
       public         heap    postgres    false            �            1259    24644    film_category    TABLE     �   CREATE TABLE public.film_category (
    film_id smallint NOT NULL,
    category_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
 !   DROP TABLE public.film_category;
       public         heap    postgres    false            �            1259    24648 
   actor_info    VIEW     8  CREATE VIEW public.actor_info AS
 SELECT a.actor_id,
    a.first_name,
    a.last_name,
    public.group_concat(DISTINCT (((c.name)::text || ': '::text) || ( SELECT public.group_concat((f.title)::text) AS group_concat
           FROM ((public.film f
             JOIN public.film_category fc_1 ON ((f.film_id = fc_1.film_id)))
             JOIN public.film_actor fa_1 ON ((f.film_id = fa_1.film_id)))
          WHERE ((fc_1.category_id = c.category_id) AND (fa_1.actor_id = a.actor_id))
          GROUP BY fa_1.actor_id))) AS film_info
   FROM (((public.actor a
     LEFT JOIN public.film_actor fa ON ((a.actor_id = fa.actor_id)))
     LEFT JOIN public.film_category fc ON ((fa.film_id = fc.film_id)))
     LEFT JOIN public.category c ON ((fc.category_id = c.category_id)))
  GROUP BY a.actor_id, a.first_name, a.last_name;
    DROP VIEW public.actor_info;
       public          postgres    false    939    212    212    212    214    214    217    216    218    216    218    217            �            1259    24653    address_address_id_seq    SEQUENCE        CREATE SEQUENCE public.address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.address_address_id_seq;
       public          postgres    false            �            1259    24654    address    TABLE     �  CREATE TABLE public.address (
    address_id integer DEFAULT nextval('public.address_address_id_seq'::regclass) NOT NULL,
    address character varying(50) NOT NULL,
    address2 character varying(50),
    district character varying(20) NOT NULL,
    city_id smallint NOT NULL,
    postal_code character varying(10),
    phone character varying(20) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.address;
       public         heap    postgres    false    220            �            1259    24659    city_city_id_seq    SEQUENCE     y   CREATE SEQUENCE public.city_city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.city_city_id_seq;
       public          postgres    false            �            1259    24660    city    TABLE     �   CREATE TABLE public.city (
    city_id integer DEFAULT nextval('public.city_city_id_seq'::regclass) NOT NULL,
    city character varying(50) NOT NULL,
    country_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.city;
       public         heap    postgres    false    222            �            1259    24665    country_country_id_seq    SEQUENCE        CREATE SEQUENCE public.country_country_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.country_country_id_seq;
       public          postgres    false            �            1259    24666    country    TABLE     �   CREATE TABLE public.country (
    country_id integer DEFAULT nextval('public.country_country_id_seq'::regclass) NOT NULL,
    country character varying(50) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.country;
       public         heap    postgres    false    224            �            1259    24671    customer_list    VIEW     R  CREATE VIEW public.customer_list AS
 SELECT cu.customer_id AS id,
    (((cu.first_name)::text || ' '::text) || (cu.last_name)::text) AS name,
    a.address,
    a.postal_code AS "zip code",
    a.phone,
    city.city,
    country.country,
        CASE
            WHEN cu.activebool THEN 'active'::text
            ELSE ''::text
        END AS notes,
    cu.store_id AS sid
   FROM (((public.customer cu
     JOIN public.address a ON ((cu.address_id = a.address_id)))
     JOIN public.city ON ((a.city_id = city.city_id)))
     JOIN public.country ON ((city.country_id = country.country_id)));
     DROP VIEW public.customer_list;
       public          postgres    false    221    210    210    210    210    210    210    221    221    221    221    223    223    223    225    225            �            1259    24676 	   film_list    VIEW     �  CREATE VIEW public.film_list AS
 SELECT film.film_id AS fid,
    film.title,
    film.description,
    category.name AS category,
    film.rental_rate AS price,
    film.length,
    film.rating,
    public.group_concat((((actor.first_name)::text || ' '::text) || (actor.last_name)::text)) AS actors
   FROM ((((public.category
     LEFT JOIN public.film_category ON ((category.category_id = film_category.category_id)))
     LEFT JOIN public.film ON ((film_category.film_id = film.film_id)))
     JOIN public.film_actor ON ((film.film_id = film_actor.film_id)))
     JOIN public.actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;
    DROP VIEW public.film_list;
       public          postgres    false    939    214    212    212    212    218    218    217    217    216    216    216    216    216    216    214    865            �            1259    24681    inventory_inventory_id_seq    SEQUENCE     �   CREATE SEQUENCE public.inventory_inventory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.inventory_inventory_id_seq;
       public          postgres    false            �            1259    24682 	   inventory    TABLE       CREATE TABLE public.inventory (
    inventory_id integer DEFAULT nextval('public.inventory_inventory_id_seq'::regclass) NOT NULL,
    film_id smallint NOT NULL,
    store_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.inventory;
       public         heap    postgres    false    228            �            1259    24687    language_language_id_seq    SEQUENCE     �   CREATE SEQUENCE public.language_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.language_language_id_seq;
       public          postgres    false            �            1259    24688    language    TABLE     �   CREATE TABLE public.language (
    language_id integer DEFAULT nextval('public.language_language_id_seq'::regclass) NOT NULL,
    name character(20) NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.language;
       public         heap    postgres    false    230            �            1259    24693    nicer_but_slower_film_list    VIEW     �  CREATE VIEW public.nicer_but_slower_film_list AS
 SELECT film.film_id AS fid,
    film.title,
    film.description,
    category.name AS category,
    film.rental_rate AS price,
    film.length,
    film.rating,
    public.group_concat((((upper("substring"((actor.first_name)::text, 1, 1)) || lower("substring"((actor.first_name)::text, 2))) || upper("substring"((actor.last_name)::text, 1, 1))) || lower("substring"((actor.last_name)::text, 2)))) AS actors
   FROM ((((public.category
     LEFT JOIN public.film_category ON ((category.category_id = film_category.category_id)))
     LEFT JOIN public.film ON ((film_category.film_id = film.film_id)))
     JOIN public.film_actor ON ((film.film_id = film_actor.film_id)))
     JOIN public.actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;
 -   DROP VIEW public.nicer_but_slower_film_list;
       public          postgres    false    939    216    216    216    217    217    218    218    212    212    212    214    214    216    216    216    865            �            1259    24698    payment_payment_id_seq    SEQUENCE        CREATE SEQUENCE public.payment_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.payment_payment_id_seq;
       public          postgres    false            �            1259    24699    payment    TABLE     8  CREATE TABLE public.payment (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id smallint NOT NULL,
    staff_id smallint NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp without time zone NOT NULL
);
    DROP TABLE public.payment;
       public         heap    postgres    false    233            �            1259    24703    rental_rental_id_seq    SEQUENCE     }   CREATE SEQUENCE public.rental_rental_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.rental_rental_id_seq;
       public          postgres    false            �            1259    24704    rental    TABLE     �  CREATE TABLE public.rental (
    rental_id integer DEFAULT nextval('public.rental_rental_id_seq'::regclass) NOT NULL,
    rental_date timestamp without time zone NOT NULL,
    inventory_id integer NOT NULL,
    customer_id smallint NOT NULL,
    return_date timestamp without time zone,
    staff_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.rental;
       public         heap    postgres    false    235            �            1259    24709    sales_by_film_category    VIEW     �  CREATE VIEW public.sales_by_film_category AS
 SELECT c.name AS category,
    sum(p.amount) AS total_sales
   FROM (((((public.payment p
     JOIN public.rental r ON ((p.rental_id = r.rental_id)))
     JOIN public.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN public.film f ON ((i.film_id = f.film_id)))
     JOIN public.film_category fc ON ((f.film_id = fc.film_id)))
     JOIN public.category c ON ((fc.category_id = c.category_id)))
  GROUP BY c.name
  ORDER BY (sum(p.amount)) DESC;
 )   DROP VIEW public.sales_by_film_category;
       public          postgres    false    236    236    234    234    229    229    218    218    216    214    214            �            1259    24714    staff_staff_id_seq    SEQUENCE     {   CREATE SEQUENCE public.staff_staff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.staff_staff_id_seq;
       public          postgres    false            �            1259    24715    staff    TABLE       CREATE TABLE public.staff (
    staff_id integer DEFAULT nextval('public.staff_staff_id_seq'::regclass) NOT NULL,
    first_name character varying(45) NOT NULL,
    last_name character varying(45) NOT NULL,
    address_id smallint NOT NULL,
    email character varying(50),
    store_id smallint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    username character varying(16) NOT NULL,
    password character varying(40),
    last_update timestamp without time zone DEFAULT now() NOT NULL,
    picture bytea
);
    DROP TABLE public.staff;
       public         heap    postgres    false    238            �            1259    24723    store_store_id_seq    SEQUENCE     {   CREATE SEQUENCE public.store_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.store_store_id_seq;
       public          postgres    false            �            1259    24724    store    TABLE       CREATE TABLE public.store (
    store_id integer DEFAULT nextval('public.store_store_id_seq'::regclass) NOT NULL,
    manager_staff_id smallint NOT NULL,
    address_id smallint NOT NULL,
    last_update timestamp without time zone DEFAULT now() NOT NULL
);
    DROP TABLE public.store;
       public         heap    postgres    false    240            �            1259    24729    sales_by_store    VIEW       CREATE VIEW public.sales_by_store AS
 SELECT (((c.city)::text || ','::text) || (cy.country)::text) AS store,
    (((m.first_name)::text || ' '::text) || (m.last_name)::text) AS manager,
    sum(p.amount) AS total_sales
   FROM (((((((public.payment p
     JOIN public.rental r ON ((p.rental_id = r.rental_id)))
     JOIN public.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN public.store s ON ((i.store_id = s.store_id)))
     JOIN public.address a ON ((s.address_id = a.address_id)))
     JOIN public.city c ON ((a.city_id = c.city_id)))
     JOIN public.country cy ON ((c.country_id = cy.country_id)))
     JOIN public.staff m ON ((s.manager_staff_id = m.staff_id)))
  GROUP BY cy.country, c.city, s.store_id, m.first_name, m.last_name
  ORDER BY cy.country, c.city;
 !   DROP VIEW public.sales_by_store;
       public          postgres    false    239    239    225    225    223    239    236    236    234    223    223    221    221    241    234    229    229    241    241            �            1259    24734 
   staff_list    VIEW     �  CREATE VIEW public.staff_list AS
 SELECT s.staff_id AS id,
    (((s.first_name)::text || ' '::text) || (s.last_name)::text) AS name,
    a.address,
    a.postal_code AS "zip code",
    a.phone,
    city.city,
    country.country,
    s.store_id AS sid
   FROM (((public.staff s
     JOIN public.address a ON ((s.address_id = a.address_id)))
     JOIN public.city ON ((a.city_id = city.city_id)))
     JOIN public.country ON ((city.country_id = country.country_id)));
    DROP VIEW public.staff_list;
       public          postgres    false    225    225    223    223    223    221    221    221    221    221    239    239    239    239    239            �          0    24617    actor 
   TABLE DATA           M   COPY public.actor (actor_id, first_name, last_name, last_update) FROM stdin;
    public          postgres    false    212   ��       �          0    24654    address 
   TABLE DATA           t   COPY public.address (address_id, address, address2, district, city_id, postal_code, phone, last_update) FROM stdin;
    public          postgres    false    221   ��       �          0    24623    category 
   TABLE DATA           B   COPY public.category (category_id, name, last_update) FROM stdin;
    public          postgres    false    214   <+      �          0    24660    city 
   TABLE DATA           F   COPY public.city (city_id, city, country_id, last_update) FROM stdin;
    public          postgres    false    223   �+      �          0    24666    country 
   TABLE DATA           C   COPY public.country (country_id, country, last_update) FROM stdin;
    public          postgres    false    225   |C      �          0    24607    customer 
   TABLE DATA           �   COPY public.customer (customer_id, store_id, first_name, last_name, email, address_id, activebool, create_date, last_update, active) FROM stdin;
    public          postgres    false    210   gG      �          0    24629    film 
   TABLE DATA           �   COPY public.film (film_id, title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features, fulltext) FROM stdin;
    public          postgres    false    216   z      �          0    24640 
   film_actor 
   TABLE DATA           D   COPY public.film_actor (actor_id, film_id, last_update) FROM stdin;
    public          postgres    false    217   ��      �          0    24644    film_category 
   TABLE DATA           J   COPY public.film_category (film_id, category_id, last_update) FROM stdin;
    public          postgres    false    218   w�      �          0    24682 	   inventory 
   TABLE DATA           Q   COPY public.inventory (inventory_id, film_id, store_id, last_update) FROM stdin;
    public          postgres    false    229   ��      �          0    24688    language 
   TABLE DATA           B   COPY public.language (language_id, name, last_update) FROM stdin;
    public          postgres    false    231   �      �          0    24699    payment 
   TABLE DATA           e   COPY public.payment (payment_id, customer_id, staff_id, rental_id, amount, payment_date) FROM stdin;
    public          postgres    false    234         �          0    24704    rental 
   TABLE DATA           w   COPY public.rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id, last_update) FROM stdin;
    public          postgres    false    236   �       �          0    24715    staff 
   TABLE DATA           �   COPY public.staff (staff_id, first_name, last_name, address_id, email, store_id, active, username, password, last_update, picture) FROM stdin;
    public          postgres    false    239   �-      �          0    24724    store 
   TABLE DATA           T   COPY public.store (store_id, manager_staff_id, address_id, last_update) FROM stdin;
    public          postgres    false    241   g.      �           0    0    actor_actor_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.actor_actor_id_seq', 200, true);
          public          postgres    false    211            �           0    0    address_address_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.address_address_id_seq', 605, true);
          public          postgres    false    220            �           0    0    category_category_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.category_category_id_seq', 16, true);
          public          postgres    false    213                        0    0    city_city_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.city_city_id_seq', 600, true);
          public          postgres    false    222                       0    0    country_country_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.country_country_id_seq', 109, true);
          public          postgres    false    224                       0    0    customer_customer_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.customer_customer_id_seq', 599, true);
          public          postgres    false    209                       0    0    film_film_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.film_film_id_seq', 1000, true);
          public          postgres    false    215                       0    0    inventory_inventory_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.inventory_inventory_id_seq', 4581, true);
          public          postgres    false    228                       0    0    language_language_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.language_language_id_seq', 6, true);
          public          postgres    false    230                       0    0    payment_payment_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.payment_payment_id_seq', 32098, true);
          public          postgres    false    233                       0    0    rental_rental_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.rental_rental_id_seq', 16049, true);
          public          postgres    false    235                       0    0    staff_staff_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.staff_staff_id_seq', 2, true);
          public          postgres    false    238            	           0    0    store_store_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.store_store_id_seq', 2, true);
          public          postgres    false    240            �           2606    24740    actor actor_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.actor
    ADD CONSTRAINT actor_pkey PRIMARY KEY (actor_id);
 :   ALTER TABLE ONLY public.actor DROP CONSTRAINT actor_pkey;
       public            postgres    false    212                       2606    24742    address address_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);
 >   ALTER TABLE ONLY public.address DROP CONSTRAINT address_pkey;
       public            postgres    false    221                       2606    24744    category category_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (category_id);
 @   ALTER TABLE ONLY public.category DROP CONSTRAINT category_pkey;
       public            postgres    false    214                       2606    24746    city city_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY public.city
    ADD CONSTRAINT city_pkey PRIMARY KEY (city_id);
 8   ALTER TABLE ONLY public.city DROP CONSTRAINT city_pkey;
       public            postgres    false    223                       2606    24748    country country_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.country
    ADD CONSTRAINT country_pkey PRIMARY KEY (country_id);
 >   ALTER TABLE ONLY public.country DROP CONSTRAINT country_pkey;
       public            postgres    false    225            �           2606    24750    customer customer_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);
 @   ALTER TABLE ONLY public.customer DROP CONSTRAINT customer_pkey;
       public            postgres    false    210            	           2606    24752    film_actor film_actor_pkey 
   CONSTRAINT     g   ALTER TABLE ONLY public.film_actor
    ADD CONSTRAINT film_actor_pkey PRIMARY KEY (actor_id, film_id);
 D   ALTER TABLE ONLY public.film_actor DROP CONSTRAINT film_actor_pkey;
       public            postgres    false    217    217                       2606    24754     film_category film_category_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.film_category
    ADD CONSTRAINT film_category_pkey PRIMARY KEY (film_id, category_id);
 J   ALTER TABLE ONLY public.film_category DROP CONSTRAINT film_category_pkey;
       public            postgres    false    218    218                       2606    24756    film film_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY public.film
    ADD CONSTRAINT film_pkey PRIMARY KEY (film_id);
 8   ALTER TABLE ONLY public.film DROP CONSTRAINT film_pkey;
       public            postgres    false    216                       2606    24758    inventory inventory_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);
 B   ALTER TABLE ONLY public.inventory DROP CONSTRAINT inventory_pkey;
       public            postgres    false    229                       2606    24760    language language_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.language
    ADD CONSTRAINT language_pkey PRIMARY KEY (language_id);
 @   ALTER TABLE ONLY public.language DROP CONSTRAINT language_pkey;
       public            postgres    false    231                       2606    24762    payment payment_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);
 >   ALTER TABLE ONLY public.payment DROP CONSTRAINT payment_pkey;
       public            postgres    false    234            "           2606    24764    rental rental_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY public.rental
    ADD CONSTRAINT rental_pkey PRIMARY KEY (rental_id);
 <   ALTER TABLE ONLY public.rental DROP CONSTRAINT rental_pkey;
       public            postgres    false    236            $           2606    24766    staff staff_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);
 :   ALTER TABLE ONLY public.staff DROP CONSTRAINT staff_pkey;
       public            postgres    false    239            '           2606    24768    store store_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.store
    ADD CONSTRAINT store_pkey PRIMARY KEY (store_id);
 :   ALTER TABLE ONLY public.store DROP CONSTRAINT store_pkey;
       public            postgres    false    241                       1259    24769    film_fulltext_idx    INDEX     E   CREATE INDEX film_fulltext_idx ON public.film USING gist (fulltext);
 %   DROP INDEX public.film_fulltext_idx;
       public            postgres    false    216                        1259    24770    idx_actor_last_name    INDEX     J   CREATE INDEX idx_actor_last_name ON public.actor USING btree (last_name);
 '   DROP INDEX public.idx_actor_last_name;
       public            postgres    false    212            �           1259    24771    idx_fk_address_id    INDEX     L   CREATE INDEX idx_fk_address_id ON public.customer USING btree (address_id);
 %   DROP INDEX public.idx_fk_address_id;
       public            postgres    false    210                       1259    24772    idx_fk_city_id    INDEX     E   CREATE INDEX idx_fk_city_id ON public.address USING btree (city_id);
 "   DROP INDEX public.idx_fk_city_id;
       public            postgres    false    221                       1259    24773    idx_fk_country_id    INDEX     H   CREATE INDEX idx_fk_country_id ON public.city USING btree (country_id);
 %   DROP INDEX public.idx_fk_country_id;
       public            postgres    false    223                       1259    24774    idx_fk_customer_id    INDEX     M   CREATE INDEX idx_fk_customer_id ON public.payment USING btree (customer_id);
 &   DROP INDEX public.idx_fk_customer_id;
       public            postgres    false    234            
           1259    24775    idx_fk_film_id    INDEX     H   CREATE INDEX idx_fk_film_id ON public.film_actor USING btree (film_id);
 "   DROP INDEX public.idx_fk_film_id;
       public            postgres    false    217                       1259    24776    idx_fk_inventory_id    INDEX     N   CREATE INDEX idx_fk_inventory_id ON public.rental USING btree (inventory_id);
 '   DROP INDEX public.idx_fk_inventory_id;
       public            postgres    false    236                       1259    24777    idx_fk_language_id    INDEX     J   CREATE INDEX idx_fk_language_id ON public.film USING btree (language_id);
 &   DROP INDEX public.idx_fk_language_id;
       public            postgres    false    216                       1259    24778    idx_fk_rental_id    INDEX     I   CREATE INDEX idx_fk_rental_id ON public.payment USING btree (rental_id);
 $   DROP INDEX public.idx_fk_rental_id;
       public            postgres    false    234                       1259    24779    idx_fk_staff_id    INDEX     G   CREATE INDEX idx_fk_staff_id ON public.payment USING btree (staff_id);
 #   DROP INDEX public.idx_fk_staff_id;
       public            postgres    false    234            �           1259    24780    idx_fk_store_id    INDEX     H   CREATE INDEX idx_fk_store_id ON public.customer USING btree (store_id);
 #   DROP INDEX public.idx_fk_store_id;
       public            postgres    false    210            �           1259    24781    idx_last_name    INDEX     G   CREATE INDEX idx_last_name ON public.customer USING btree (last_name);
 !   DROP INDEX public.idx_last_name;
       public            postgres    false    210                       1259    24782    idx_store_id_film_id    INDEX     W   CREATE INDEX idx_store_id_film_id ON public.inventory USING btree (store_id, film_id);
 (   DROP INDEX public.idx_store_id_film_id;
       public            postgres    false    229    229                       1259    24783 	   idx_title    INDEX     ;   CREATE INDEX idx_title ON public.film USING btree (title);
    DROP INDEX public.idx_title;
       public            postgres    false    216            %           1259    24784    idx_unq_manager_staff_id    INDEX     ]   CREATE UNIQUE INDEX idx_unq_manager_staff_id ON public.store USING btree (manager_staff_id);
 ,   DROP INDEX public.idx_unq_manager_staff_id;
       public            postgres    false    241                        1259    24785 3   idx_unq_rental_rental_date_inventory_id_customer_id    INDEX     �   CREATE UNIQUE INDEX idx_unq_rental_rental_date_inventory_id_customer_id ON public.rental USING btree (rental_date, inventory_id, customer_id);
 G   DROP INDEX public.idx_unq_rental_rental_date_inventory_id_customer_id;
       public            postgres    false    236    236    236            =           2620    24786    film film_fulltext_trigger    TRIGGER     �   CREATE TRIGGER film_fulltext_trigger BEFORE INSERT OR UPDATE ON public.film FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('fulltext', 'pg_catalog.english', 'title', 'description');
 3   DROP TRIGGER film_fulltext_trigger ON public.film;
       public          postgres    false    216            ;           2620    24787    actor last_updated    TRIGGER     o   CREATE TRIGGER last_updated BEFORE UPDATE ON public.actor FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 +   DROP TRIGGER last_updated ON public.actor;
       public          postgres    false    262    212            A           2620    24788    address last_updated    TRIGGER     q   CREATE TRIGGER last_updated BEFORE UPDATE ON public.address FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 -   DROP TRIGGER last_updated ON public.address;
       public          postgres    false    221    262            <           2620    24789    category last_updated    TRIGGER     r   CREATE TRIGGER last_updated BEFORE UPDATE ON public.category FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 .   DROP TRIGGER last_updated ON public.category;
       public          postgres    false    262    214            B           2620    24790    city last_updated    TRIGGER     n   CREATE TRIGGER last_updated BEFORE UPDATE ON public.city FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 *   DROP TRIGGER last_updated ON public.city;
       public          postgres    false    223    262            C           2620    24791    country last_updated    TRIGGER     q   CREATE TRIGGER last_updated BEFORE UPDATE ON public.country FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 -   DROP TRIGGER last_updated ON public.country;
       public          postgres    false    225    262            :           2620    24792    customer last_updated    TRIGGER     r   CREATE TRIGGER last_updated BEFORE UPDATE ON public.customer FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 .   DROP TRIGGER last_updated ON public.customer;
       public          postgres    false    262    210            >           2620    24793    film last_updated    TRIGGER     n   CREATE TRIGGER last_updated BEFORE UPDATE ON public.film FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 *   DROP TRIGGER last_updated ON public.film;
       public          postgres    false    262    216            ?           2620    24794    film_actor last_updated    TRIGGER     t   CREATE TRIGGER last_updated BEFORE UPDATE ON public.film_actor FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 0   DROP TRIGGER last_updated ON public.film_actor;
       public          postgres    false    217    262            @           2620    24795    film_category last_updated    TRIGGER     w   CREATE TRIGGER last_updated BEFORE UPDATE ON public.film_category FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 3   DROP TRIGGER last_updated ON public.film_category;
       public          postgres    false    262    218            D           2620    24796    inventory last_updated    TRIGGER     s   CREATE TRIGGER last_updated BEFORE UPDATE ON public.inventory FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 /   DROP TRIGGER last_updated ON public.inventory;
       public          postgres    false    262    229            E           2620    24797    language last_updated    TRIGGER     r   CREATE TRIGGER last_updated BEFORE UPDATE ON public.language FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 .   DROP TRIGGER last_updated ON public.language;
       public          postgres    false    231    262            F           2620    24798    rental last_updated    TRIGGER     p   CREATE TRIGGER last_updated BEFORE UPDATE ON public.rental FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 ,   DROP TRIGGER last_updated ON public.rental;
       public          postgres    false    236    262            G           2620    24799    staff last_updated    TRIGGER     o   CREATE TRIGGER last_updated BEFORE UPDATE ON public.staff FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 +   DROP TRIGGER last_updated ON public.staff;
       public          postgres    false    262    239            H           2620    24800    store last_updated    TRIGGER     o   CREATE TRIGGER last_updated BEFORE UPDATE ON public.store FOR EACH ROW EXECUTE FUNCTION public.last_updated();
 +   DROP TRIGGER last_updated ON public.store;
       public          postgres    false    262    241            (           2606    24801 !   customer customer_address_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 K   ALTER TABLE ONLY public.customer DROP CONSTRAINT customer_address_id_fkey;
       public          postgres    false    3598    221    210            *           2606    24806 #   film_actor film_actor_actor_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.film_actor
    ADD CONSTRAINT film_actor_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actor(actor_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 M   ALTER TABLE ONLY public.film_actor DROP CONSTRAINT film_actor_actor_id_fkey;
       public          postgres    false    212    217    3583            +           2606    24811 "   film_actor film_actor_film_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.film_actor
    ADD CONSTRAINT film_actor_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 L   ALTER TABLE ONLY public.film_actor DROP CONSTRAINT film_actor_film_id_fkey;
       public          postgres    false    217    3589    216            ,           2606    24816 ,   film_category film_category_category_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.film_category
    ADD CONSTRAINT film_category_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category(category_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 V   ALTER TABLE ONLY public.film_category DROP CONSTRAINT film_category_category_id_fkey;
       public          postgres    false    214    3586    218            -           2606    24821 (   film_category film_category_film_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.film_category
    ADD CONSTRAINT film_category_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 R   ALTER TABLE ONLY public.film_category DROP CONSTRAINT film_category_film_id_fkey;
       public          postgres    false    216    3589    218            )           2606    24826    film film_language_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.film
    ADD CONSTRAINT film_language_id_fkey FOREIGN KEY (language_id) REFERENCES public.language(language_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 D   ALTER TABLE ONLY public.film DROP CONSTRAINT film_language_id_fkey;
       public          postgres    false    216    3609    231            .           2606    24831    address fk_address_city    FK CONSTRAINT     z   ALTER TABLE ONLY public.address
    ADD CONSTRAINT fk_address_city FOREIGN KEY (city_id) REFERENCES public.city(city_id);
 A   ALTER TABLE ONLY public.address DROP CONSTRAINT fk_address_city;
       public          postgres    false    3601    223    221            /           2606    24836    city fk_city    FK CONSTRAINT     x   ALTER TABLE ONLY public.city
    ADD CONSTRAINT fk_city FOREIGN KEY (country_id) REFERENCES public.country(country_id);
 6   ALTER TABLE ONLY public.city DROP CONSTRAINT fk_city;
       public          postgres    false    225    3604    223            0           2606    24841     inventory inventory_film_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 J   ALTER TABLE ONLY public.inventory DROP CONSTRAINT inventory_film_id_fkey;
       public          postgres    false    3589    229    216            1           2606    24846     payment payment_customer_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 J   ALTER TABLE ONLY public.payment DROP CONSTRAINT payment_customer_id_fkey;
       public          postgres    false    3578    234    210            2           2606    24851    payment payment_rental_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rental(rental_id) ON UPDATE CASCADE ON DELETE SET NULL;
 H   ALTER TABLE ONLY public.payment DROP CONSTRAINT payment_rental_id_fkey;
       public          postgres    false    236    234    3618            3           2606    24856    payment payment_staff_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 G   ALTER TABLE ONLY public.payment DROP CONSTRAINT payment_staff_id_fkey;
       public          postgres    false    3620    234    239            4           2606    24861    rental rental_customer_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.rental
    ADD CONSTRAINT rental_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 H   ALTER TABLE ONLY public.rental DROP CONSTRAINT rental_customer_id_fkey;
       public          postgres    false    210    3578    236            5           2606    24866    rental rental_inventory_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.rental
    ADD CONSTRAINT rental_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(inventory_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 I   ALTER TABLE ONLY public.rental DROP CONSTRAINT rental_inventory_id_fkey;
       public          postgres    false    236    3607    229            6           2606    24871    rental rental_staff_id_key    FK CONSTRAINT     �   ALTER TABLE ONLY public.rental
    ADD CONSTRAINT rental_staff_id_key FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);
 D   ALTER TABLE ONLY public.rental DROP CONSTRAINT rental_staff_id_key;
       public          postgres    false    3620    239    236            7           2606    24876    staff staff_address_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 E   ALTER TABLE ONLY public.staff DROP CONSTRAINT staff_address_id_fkey;
       public          postgres    false    239    221    3598            8           2606    24881    store store_address_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.store
    ADD CONSTRAINT store_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 E   ALTER TABLE ONLY public.store DROP CONSTRAINT store_address_id_fkey;
       public          postgres    false    221    3598    241            9           2606    24886 !   store store_manager_staff_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.store
    ADD CONSTRAINT store_manager_staff_id_fkey FOREIGN KEY (manager_staff_id) REFERENCES public.staff(staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;
 K   ALTER TABLE ONLY public.store DROP CONSTRAINT store_manager_staff_id_fkey;
       public          postgres    false    3620    241    239            �   �  x����r�:���S���;�ζr����%y⪩�@$����y��A]�7d�M�D�/�_��7�Hm��=���m��'_��k�����şY�G��wU�ه�镴[*,a���i'ZIE�l&�Fm�eqR�363��ث�ڬ�ڪ���s�(�N�w�ݚ�
,س�ds�vRSQ%����ɳ{Ѵ��"��,�=�#dĪ�S�a�b���p��-�aObK���EX��v ����`Ƭɐ��T'%�K[I~ ��S��vі��_V��Hl�	+�Tj<��Q�]G��h���K�W�͊�%�5JO�m�^�Zi���'s��,z�aoBw֜�Ș}Ӯo����J�R4k+��@�#NQk�?�k�Y)�d`�^�I�Xژ���:�'+�c�����Z	6���K��q9v���f�9:�bZ���!�6�n)y�59+	gKն[����^��1{W6���fI��(~��){��V�O�I=�1��'B�z۱I�{Zݒ��b���畘����Z�eJ*�l�ZI�h]�(�n�ꓗ�#���DB���'����EYIeN7X{��ɜ��d\zY0�N@��6J3����?Xi�9�{���6Vz�GA=K?��ĉ�FJ&b��*�t}S�D��x�hd岈}�`�{j�{��ېcs@��vF6�ԝ,Fq��2�R3L�l{��#����os𦚽Ge�:<J�壦O�f��w�X�����Y�i�>�H��*�"�LDߙ�tS�{�j�?=�;��6y�f�����~p��ߠ�3��VB������5 )�9�K�j7JK:���XK�K�
;C��B;�� +�Ωԯ6��;��gkqp֎n�"fK���J�,���Uɘ��V^����"��7�z^>�TLa �N(Z���M��[))���c�6���@:A�V|���q����]Û:����}e|53㴏�J0�ׂ��*���E�S��^�	{��Yzv.��Z���ϖ/s�Wn�Q92�`ˣ�ư^R��lk��{���[��L������njf�;��W���n���[G����ь*����WZ�:H�J�uh�����b	��d�U��;��[� U`?XP?J�(���DI��#Oߢh^*�F�_��Q���U����O[�oVx�AK�J��3�Q~מIߴ4�E�q'{A��#�|�����q[�$�nL�'A���I7������4_�m�8��>��Dy��:;��}�~���kc!�4��/�
o�(|g���#'�/P� 9s��x x�1
�_+8�#��;rnk<��^�/1^0�?��/�A��>��3�^}�����ÎR)K�����=<���J�K���/� ��k����d��9��"����c�u!��A�3�$�J����虫ĭ��o�ue ?���L��
_��C:���9���(�=y)nCr�L;HM$�`�og��a�|����sT���Vڔ_Z�_<u��_k�CJo��al{4��� �lI�: ׯC$`w��Z�vPz��~Sl?s���S�8]�J�k�k��`ugo%q�~��~�����tS��V�����N�>��`�1Ǿ�qV\�`.��w?.�fѢ�}�P�WуU��,�_�~CVGnO�n��a1�q�bʯ�Of�Cz�h}��;�~?��렔���X�)��]
��|jmh���v�v�_�|�� %r��t �=�J���T��/6��ɠ�����tH������ ��"uh}�ᯏݚ9H~�4z������
u9�U�"d���XQ������l��a���%�A�7txr���C`�D�V�&?r��Mf���d��48����ZC����/'ް�/o���g��7X�#?w���3	Z����e��uwu0���/ ��c?�$,�%��*����n�oq��eG�N�U�o��C���fq��{�*/�̀/u�>6B�{�:���/_��L�v�      �      x���Yw�F�����j�x���ol��hKvuy�HBL��	��L������H*���������3�cV6��=|��M�욯��߯�m.��P��8^�VIgqra\��m���%�����6z����k�]�'}�r��,��U�F�j��u���Eo���?��8��ˊ�kX�c���f�p]m��W�?;3y�h��<��[�Ҥ��j�6ѿ����}uS�u+�����i{����I�]$[��3��*z����j���4_�n�T+k˕ɋ"[i�i�"�����WY�D����>D�]]V�g�Cs�)��]^j���)c�?�be\�E?��M�N[�V+�E'����.u�Y�+t±�(?��1���K}���o���m�J��m���X��zl����&��K}�l��6�������j��?�����~����"���b�,�lXԬ�8�9�zw�M���.uI�ʴ(�Un2��$��<=�=�b�����m�9�;~�*�K[��HR$I����`�T�Foڮճ�SW���:��DW�
ku�:��%IH,�ݥF�L����R����d�n)K�5�(\V�j
w~���I���6����T;��7U�K�2O�<���$�q=_���,b���AK�\� ��0sE�q��EJ��8z������>�ծy�u2�se&!�Jg�2+r��zS�V�����M��z<�Ms`Y�r&׋N��8�C]�)��7�M5j']���A��U��~��z���Ū,���;�M��4���Ҏm����qw���\Yɾ���si��$h����L�?2��n�pu�����t��k�6�%V��LWrv�Db�C���a>�7�u�kL�.P�!E!uSW�8;/�I�"�9��J����z�v�u����}�J�\GfJ}L���H����H䳢�>�Uݨ&޷��7>�y�]�g|�گ�|��p���pd���꦳$z&]��U���j����庒�u��������#���j���0~/�zR��PK�%m����.�Å��ş�v���şze�+�sF4��T*/	��c8��u�k�W����[�d*��c,�j%6I\I����������n/y�o�9�F���4px��W�=h��z����ݏ��u}�T�j�����(K}�L�����qv���˾�_���r��>#��-�+��%�a��&���a��.���+	᧶��K�])}���2��d1N��Z�$-!�����nRw�ݺ�$�p��Y.[��q`%]V�E����@��ն���2���J�g����]�Ǒѳݽ,�~>�ϕn�Y��}�$9q�Y��y�)헦�+�ݡ҉y���d��F�,5�#g2w��6m��t����,�F���n���p��Yq
8h�	�Q�+֪&��T/ �%eݮ֓寍�x�z���cW�L�D� �޲�Q���!l��*��C�+t�2*<�,��a���H�m6U;��溹���/�K�ˬ�X&��$�2��)���Y��w7Rj?�ӱ���6����SC��imQ�A6��3�UG?�w=�.m�e��������)K]H�],#}~-����6��ڭ�j��]���'3Ak[H�t\e���Z�X�/���-e1�Ə����̵+��V���F��d��7��r����MvM����J�i&�!;�i���#Md�����]w�@;�ɴ���
vKh�����Vj���;H�����''��)�'����;̣���~��պ94|�m}��H��^�^�T@!�F���{�ҷR���
��g��H��' �V����C.��9���uʢ��R�xL
�Ys�I��,�x[�����M����o�/���?%W8��4�l��P���%)�Lz��vw=���s������ V�"�Q2Vq�t�ϲj�v���7�W�&9MB�k&�ӻ�~�����D���-�I��n�g�xR���H�~�H���9�u��C��i��I�JiѴtq@)N�ߤ���~�쵵�c^��ܠ]�?�mi���Da�i	������-�J�]��г �^�����P��Do�@6K�/#l"�]J��ld�3lk��£����}�(o��}}_?�s�ף�M���e�u82�}*����G��6� 7���6��qI�]�U>��.���$z`p��G������A��L�2>vTMZ��Q�f�@#�̚�q�;yw�1p�����T�ޛ�"'�m����fgW�20�F#�<�9a�o՝,dB��+���i��@�(��b:t�Kg���Qϐ�����������5�rh���u��0����}�p"!���1�3!	y��	��?���z:��վ�\|:Tׇ�S�PH�Km�Ԝ��@Gr�����⢌J���[��܇U�\�O���ev�ѩ/�P�eW�9$�!J=[�8��
!>�?�lr�'���Z�
�Y�%
 �޵<���Յlp&����gxQ=�;��hG9ή�KY��L�t��`V���7��j��2��Ow�:�H�
���e򶤝�<��i*����v���=����nJ�,�52���/�wy��Ca���ī�9�ԣ�[�k�FXP2�&zY�7���f�?���+��W�Y�8�۵�A{��s�}b��p����w�,�� .np�SK���@���t�?z�|�!�P�E�%�O�?��Dvɝ̹�EЭ�)��5ow�G��~�o���rAa8��,��BBmt�z������u�b�! #s�� �<I��)=�fA�'�^j�_{�K�N�.�ߴ+�fB��zd]�Yq��IԌw�Gpx�r��ؿ�@T	(O������Ghc�!�n�����i�%5�Ve!m�BY�f
,DA����l0D�Rl�D��G$��gY K�K�\|�����S�M�+� ����_.5G��C=(�9��H��t��3��
H���1��|xh�D��7_�Cd��)�E�᪚�fw|�蝹Զ<\9V8>�&��YS�
�(�>ן��o�u-�Z�l��U�h�$���/�k�R~��Ժ���zP�A��^0@Q֑x�̥� b�"��^�F0��\U�����Љ�./�nV��M�uϯ�%]��P�+M!�<!�-��ig��+��y�����>�Ͻ[�M�9QOi8��"�h�ہR�GJTJ�;�_���=�����W�
x	ǔ�2�%n�wX�{���h�e���m}�o��%�+y�e!w[��<P�0e�E?n�"�OB�K�<k�z/�$���+��Y�?8/I��Q�����	���n�up��2I�t��gʑ+���e��������~W7ξ�]��Q�W2d�dr�v�u��P���/_��ų��V=/��m�z�)IOKȺ��-M���>�s)��}uF�$=1[�8�����}���b��k:��ɤ�EI�%B�o���餈t�ڪ��4+����r������9���V�+�ڔP�D_:Z���n�1ą�G}�\�A�Wu�ݐ4�<]R����] �J9]���n���vc�����'�����l���OM�>V�����]���uu)��`6U�IJ�IBȸ�h�BxbSE�i�������ys��i0u��0��#T%{ڣ�o�݁�Fc=-��%�Pj6q��re\ �PM�s��g��[Iq�3���R�rT@pWFޛ�����Yյ��-����I�� x��V���z�͌����?�L���rF1�S��hiC�T�΢��c���H-�F���_�@8P9�!c��z�dN4X\���-.T�O�_z�P2�y����N��K��`����/<��p���߇�����������AW'gW���q������2�
鏗�u����wù��^�;����H}�$�B2{��V���9�����J�&�P��<�T��o����=Ѧ�L,�9�u�0"��t#BǺHÃx�e_��M�_�A���\*�cU���xC 5�����s�u}�����I��EK�.I%�EH�	�z?zgҮ�e��P0'O`���,DG������_���T_�� ��ғ��+ ���F�    _������%|]��cr���n]7����͕�z�(���C����=}0���Np����Ŀ��$p���E�TD��G3��d��\��%�T;�n��k�6`�qׯzr5Ґ�T��s����n�D�O5��e��y��Ĳͥ0�D�ibA��E[]U�+_��}��KTm.~�6�e�PaY�b|JFN�Ǹ"�|��'����0X����v8��U���8~��tD��wC"Иh�7��v�ɻ��^#X�y�s�.ʃr7�xo�-�Y}���J!i%HS���㓛��a��ӯrc�U?/�[a��M#h�)!<�m�U�[;���1��@����	NȽ�Z�m�}rb$Y,-7�6�m��
JR͢_��~]ψ��S"1s������*�N��^W7��}��ڶz����|Z����b�Խ�q1i��z�¼]�M��kj�D{��ɍ��(�O��Ky06�ܠ����Zţz=lI�Ԋ��G&�e��6`>W��e<v�q��,%YOt7;T��"���:�u{�n�����]u����NV���!O*	�h���M	z��c�h���j�� IAl<�%�ז�^O��2s!j�j݃:�@���Ju��S}"�E����"�e��r�/���DG)9U?�oNO�^�(O+�����iu��z(c��<��گ��%ƹ��ɦDH#謥�d��L�r��=	�g��zU:�X�8�ڭ��KAֿI�d�̽w�o�d	���L���
��ETf���Nq�'��4�c�a�8�m�ǁ�Q�r��F���n��V��,(�M����@�R:}�!��]s���m�
�k�,+o��4Ϲ���8*���r�& ������k����E� �j9J�'�c�4z{�Sܺ_>]� ��a9]��7�,,�V+�{�ߞԀ5+
��\�y�
�Y'����ES8f���%$��
eTQ?y~%=����U�]0ːХ蠈�D0܄<@G��$�F%�f!��y�=�{�=�׆к@���.:z+ �n�?�N֤�,i�J �5���K�����z�y��.^J���K6_/�+����{����2=�w�~_]��}}8�W>��$��E)�R�. [Nv�0�'me���]s�G�Zi�В���Z����g�����gR.�œ��D���Jt�x@�&���n#��ј�]�}���(_��*yG����ے�~�*��>^<~�B섉~��/�T����+%XLv@�ꅴ�mt�������1bgc�0���J>��o�ʮW�sv��v+*a���\��(7Y�6I
����U3=�:��яw>+L�M�˒�uiau�!;��!L��?y�v7�F�.�2�B2EY6	�^��Г���8��ݾ�:J*j��� "F�_��EMh�t�Y��c|�ϴ���,�bb��2*�O��,�)HғX����L���r� ��W��Tt�+%q�o���7O>�N-� �m|bD�@r�|��ñ���X=�����ȿM�Y�	0�s8->'y~I�2��#1��rzï�/�tIJU�%�.��7fBU	ԓr��d��]����[�z�� �,�	{&��?�rCq�� R�p�]*���M|Zz���䦫�ǈ��f#y�VY��
�Ҹ���˺�u�զ�v��?�6BwY�QV���5�~�����^ݳ.A�ԕ�'�)�<5�_�/´�W���I5��LFO���	s!{Cj������u�O��\>���1H=Զ��9y��Q9jK�߻���Ủ˺�8$!l0]B�R ��B��Τ=&�3�� ���ܭp{dRK)�>(�����7����_���p�uSw[��w�eO�å&�|eE��
*o��r<�9�k:��+�/��Z�X���$��:���azC���%H(���S�}~!Y�g���`�;q,>�5w�$�Rń�%ܞ6��]8�S��­���"\J
�W�%+�8��h3Z=��D�5���$�x�ܩYȓ��d�n![��>me����e�Sk(��7u��)[�[p,��b��H�.P�1.dq�ʜz��
��y����&�{�ν�KZI7���Ut��a8"y��Nt�I�JF��M�$�0;�(, ���_�u��;�؇(g�ډ�Us�9.L ih
�M�l{YǢ��m�]_<邏v	xA���IH���"-B��(��ywE�X\�b����M�U�NPE+SnIݴdP>���y@Y��R��3���t�8p�x.I���{���;:����%�Eぬ�pj�{�H,��GS]Ȣ�ʧ��'�Q��s!S�(y��*g8x���]��q���|����Ie��L���Fm�lI��<JC�Z�Z<�@r�C�E��S'��.~k����Ů�x��h��?-�qI�����9f��57���~��������YCJ�e%�R8.)�㤸�Sߍ~�`~��=R�lP����U�
��� 0}د���O�s{��^�,�(:�b]���jy D2	u֛zD���U_�������AÚ���C���M�DǄ��S+��PKv�C����}�,}�\�uSK��i&�,"Ӻ)�)�쁊P�W�%�V��DY�ġ.9,���ֻ�����I�;�Ź0�~h^�:�)qzy��kqM���~�z0J�P"���[��1o�B��ջ��es�'p�l�[H��ɒb�H����7�u}صG��;j�2�s�+Etex'd�-�BC�lNM����; Q����-x�Rc̣D��M������~�	��㓐�N�o��o�A���;G���V*�oB))M:!ʓ~��)�-Mͫ0UA�F���d�n@b|������c7�Z��j=�I�q���]�A��>�҇�%�ԭҺxB���x�*�$j��� ���XE�"�g�̉�s�Y���\r�
$�m����`�c!S�G3y����2t��=FϤFVt��r�Qa��y ����tJ���z�U�KC��� +��Z�
<��~���������ž+j�]<�ӹ�yV�y�����Cu����v��U�����H������$6�@_I:��ک1�����SG$4f�>1t�%�\{p���"�!�]�b0��K����<�	K���m?ͣD�<)�U!���m�ܯ�$��Χu���i�dFI��ߩJ���xB��V_����l7���`�!=/%����8BM!S�nY)2�w2���F!5X�Z��m�����S@���IJ=\I3�5b`r��CJ�Rqj	_Il��f�Q�o|�
�Zz���Ƣ �Z�z�X��YW���MuwW]�X�_���N6�`��=Mw2��|��~�N�_���>\(�4.!8I���P�$���
��U����Ƀ*&�{�1�R��i��*ɬ�.�8�F�m����:>)�1�bG23�'S�9�s���پ�#�I��pdJ���@�]*6�%����u�LJ�S5���H���P���($a6PH�;wv�a��޵��c�ӫ(�t��.U�0���,��i�mu����]夒,�?p�4%(N�{�Z��Y����P:�sݔ�:���wd�ߩ���%>jM�B�Tf�R��KZwd:p�5R#�Ǭ̬�}����hXK��U_�����
*��	{������4p�rR+��#8K]�M�_@W7"�����&)�5��eAn���?�z�g�}��'z8U�2�q�]�2�t�[�?umڛ�� O�w��Qm��\b�^K~�c��*�ʁ�I2��������u����Us�;^�(���\�9��'�B$�28�w���rG����_oБ&a���8��IFL�����^$ i���(i)�4y���e�놕��8���\�-8
��t��)�=�Һ%M�!TJ��~���!��Z5kYb�LAESm#��|�r�j	�]{l?�u*J�'��e������BR���i�AANpS�R�C�����mSh;'��C�d�"
<����I)�d��q�	�HS��n���4]3ڂ��H=IGtd���	    �+yi	�1@t�J�%�@���Ό�:|�4��HK�q)��|�����Ӧ�k26Rj��"}Y�G�$2�֓�1YNr��a@_�N=��§n�/d=�ŉJ��c�v�*͍֓���ί����P#T���\�䭺Z��$�э(��R���ɖy����A&R����~ !!]����K�zd�]�0��	,��1N=���H��h�
(q����:-}����dW�ѫZ�_�O���BS�'��]��ތ��Uw��9	.��I����2��\z�N�&�J���Wu����Fv��t�r��J��@Ʋ$�f2j�M��폭����o�~G�n�U��ul!����Ąt�UH��w+�R�D��n" �d�c������`����=FH߹��@�5�F�ķ4>�__/����
�ʂrD]���K�����͒�_0v���׼�
�
�bY �K��>� f�`A1��w��~�R�%�t|K.2*�B�I�,5����e�[O��s���Hg(�H����,�(j�d�|⧽�\��q����_I�6�)�~.B�4�}�.�=�����ꉁ��(	𾞣�3�}H��	�h�:���1%�	/J�C鸐�6��Kr8��ta�inN����%�v�AHG��z~!���eR�3bӍi雂ѐ����:+)B���^�н�vxIi(@	L�%9��,Ɯs�d�I����zsG��P?+�^@�D7�$��Z(6�{:w,u8����:)�|)y�߇��2���ǘj���'W�y�Fka��jNH'[;�F���T�N_u�W�(_M?&Y�"�8�����.h�&<���(=O��<��K<)W�gu�u�_|l�]�ñ*�g9";\@�������܀�"�\Z{ß���*�5��7J��&=���A`wN|-�����r���L��i���=|�4�d���� �x@C�"�_D9E�C�$Z|�t,�g�uwY5׏����(��n�%�g�b~�5���?��ԁ�'��_:O�P/MB�
}��0�M���6Ʃ��q.W`thH��Wވ&ڧ9� ��L�/CF��t�$�[C,t�#�o��1�y	�Ё�d��2��B3��M�.���S�����$�-�A]<q���aI�?͖��oh�A��{J/��\�`�]�V�6�D�ǵ�]�I����`H��BQߦ\��/��9=+;G4��� g�	�d��v$߳ńN}G��h��OT*��j ߧl«z보����'�8��iN��7�saR:������W}�䋤Sʳ���Q��'%�5��~�(����no�(��i>pHII������29�E�FwK�A{�T�@�C����]D���EzI��J��%�(��"��,$M@E�u'���?�zy�\z�J@8�g�|T���}�MM�k �Z�wn��u�/<8Y�S�o��BÖ��C�wD�X\�W�������Z�3K�C0fq U&M)����>����VV;N��K�uu�mJ/O�����	(}�b�V��H��� ���Y���ff8���v�����0�xf݀q� �ύ�ָ�7R��_l���
K݄^AL�1PKE _�]D��G��C}�ˮZփ���P
�2i���	�O"����n���%��]�	�I*��$8�Aݎ�{�f\�[+cи�w*�%#b�`��?7'=�T�&4�@M�3��7 *t�Xk'�к-Ͳ�SR�M}]��y9y��e*�	����G����>:����Ѫ?]/Mp͝��V#`M)�rӳ���6�G=�Ә��j���+K����U�"D�+l���o��Ы�[�P�h���|��ZʘN*�V���@�!5�+�����H�I��ܲ�%P,�C�	4������HO�=ފ�!|gr�!^���vxse��BuTx��˺�;>�UB���t�.��\��])q�s;EGf�+��Mc��X���I�aZmz�$�7�L�u�V[�?��=��b�����Rl'�Ns<5Ґ�R�=t��h��[�����)
EFd����m ��&�A�џ�߯�e�Eo�a�>T݊�!�q����.�P_�z��q[}�ߵ�[H+�⣺���2���u���+�0e�F��S�Jr�j(���r�TuYF�G�ARV?�nkZ�w4�4F���.�d���8~S|L�ɘ!R(���zB4�v��kO�d�MΦxΥہp.���:IzU] �Cx������]�՛v�ߣ/}�};��$����CP�@��k�9s��,�/��g&��L�HB�������c֣<�{�π�i�@��$F:q�����y�թ�)��@�X��wz��jl�1�h�79t�����a��n�f*�_��JZ�+�2qh�������Nr9��3���5D�+�"���	$��|��z��:����6'��;�?V�3+|u'\%�1d��Ϧ���k��:l����Pc\0�R��sR�=�9��%�@ⅸ��sOTIJ�y*h��OQ�O����9��G�4I6K2}U:'�BqM�3�W���+��&�g2
OlfB�D�2��)�5m�)���M�~J@�I�T�"��1 u��)q&��$�hW�1����|D�]/����<� ��R�В�̍�C���sx��A$F��#i��H�ZI3�j�5?+&V�c)��}�sQ���Y1DiB�#+o�krfF�c�8=���*�>��M2*���2=��V9�{��'�d�-�l(ߑ}i:���.��<�4Ä�r,Hg�9v�NLZ��Cu߯R(�28u2@��&]���D(W���4<����m'�Y<iv����G����C�5sA��M]�`Hd��9�qA�X&!BN�0?�'9JW�B��u�	���ST�H�8"Z?c �T�d/y:�Ǡ��(�Ng���z=-%!�E�ې�?@�Z�r���Xv��突���:1���Hs��@��n��|��NWXt��Vx���(DF6.������������/>��$PZ"�T�NF(���);�-~�p\�mw��</�4�qL�3�w�8 vv2D���y��%��{e`m(��
,D�W��w��"�J��EL��V&g��JҐݧ��E��+�񮽗8f�&��'������>���c�F�e��z���P)T�M0V����$J`m���N�����y�[�B>Xqh��ޔ2yh��ԧ����������<����g Q�Ц}:A��T�:��ԃ+��Z~�PB�ʆ�Fec�6�%�Ӻ���Za��j=08~�E�?/2��eB���|ےL[T��W�K.C�R'$�3�o*!�����/���nO���8+�Ȉ����ά�,O*���rZ�r;��D2]|�:��E��wJ��5;pa�~��מ�=D����������N����k��l�U���
�,��G���>7�����]0���Voj�@�QYZbo�0�"�(iy�ba,Cբ��l�F�)�Δx�n�}���|k��ݨL��&��;�mK�AhV���<-~Y�IV��
�����uJ�9Ό'V���S�Uz�mfKZL\��,�MZ�Im�O�n��J?/�<��R���u�)/�����̄+%���dq�r�B���&ޙL�����'�ѫ",C��v�� R|�r8�<r��K�T����Ϳ��U�J}� <�2�)�J�FY����O����f�}�`�G�ӿ4��&�<_c<�7���tK�'Au�fB.�T���P�([�4.��m_��T_j��n�e�{�t����0��F�ѻ���ܶ_�������-(�@�6bh�nR�$=#���GX"���VJ�O`M^;l�������^Rf�QM�Ĥ	Ta9��W]�\k�����U��!�G�;d,U����e#>Y.Ym��~�����h-rE`���~�"4u8�9F���J*_��������#��Ϥ�)GM|2��Խ�"�ZXτ-��]�,)�^o���X���1��Q�J�	�:�����5����Wss    `C�dX�,s(©�f"�Ǽ����tu1u	:�����ɗ���SA�w-|�8�RH�-q& �ة�Qs�^���b>��I��+?�T�&&<F�W��fƉ�~(M#��3������!���Y�\�Eo������F �RZd�Q1sc�[�X��̼�{�/c�HyCIRA��ϕ�R� ��l�f�;���:tM�(MA�V\h.�
�������u�ܬs�3�]W]�eE҆~y!� ֐�,�87��w�]E9e�4��]�q:P�ɬ��d3Y�L8�p������'�h�������x�oڡh�&���߬�o7������S`5KGV�g��e7c����a<YB�@�>�o)q�o�~�ǔ*�[S�V�\+�<�OP ��<=�G!�pբ��$�B`a�T*,4Ĕb#���w{��J���Zr)�D� ���\�:#?5��'<�.d����Og��	⣪(�&G�;�8���ox@�\J4�!(��3O�i�`(�$a=���c`1���XF��95?���v�%Tپ�!qІ3Q1��!hB�})��/ة-$[#�1:A��S?�z�:�\
�3Z�RG�������@�?EǾ\稼��t*�vE��^�[�or��o�L��}#��.�XOH[�q�#���G�6�����;`ekh������g�􀚩 �]3����s+�\g���	��7N˼�˲�A��Dw}=�d'5U��>V�;�� �NA�&|g�n���s(�X)FjǍ�Ìid�a@)���,H��g���{�>HH�9���T�Ih����͓�D�f!��3�reaL����E���[�"����+��bkE�M�
�lB;=ا�ݬgObYG,�I��Q'p��Y�Bl0��Vj_��e6{�8K��>'aFPN/,��2��:/oc͗�C�)�.�6J�K�~V�bJ��b�.�o}�l��A�O��� ��8.�ir���iG��n�/���>m  I �c���X�_}[W���W��G=%���/G��0�tj[��a�\F6��S����	�\�� �?8q�'�;��@>T�}��$
%����u��K�(���}�dz�o�!)�uyp��0H&�����tҦL�B-���q�����0���P�>VN�[�)<�<�LB��4M%,�3%�'`=N饈Q
��
,���� "�������ou��ۯ7�RZ|ِ��KQ�34�������|E��p�����s�N�4g>/4���i e}31�l��`N^���ܨ�������+?Ԗ���@e�\ ��Չ  ���o}צ�:���^FKsS=5��8�/@g:Ù���'��g��c�qSA��r���P,���N����?�T���%$
�2���j@����Ɗ����ڮ94��4�F����bWL�j��<���"����Fˌ�U�������LF�MB�wh�_�Eo�n�8���}�]�����'"��@ːD�GJvn��3�º�P*C�;�̘��"iF��Y"�i��
�*xIv�0�<�8NK�h��W�s/���_�C��l��xr>�=?���P0`IC�0m�y&<��.�Nx����Y������JNZ~��$�Q����/K���ފ�d�y12�V�l0��|	i\.RW1���~�8�!���b�Y���*3�{�:�8�N�;�V��p5����&t!Q�R|��5�Lv�V0�./�u��I jL�<%h|��!~^5�uG�# kH	����皳c���Qݕ�T
[/?������q �����w�X��p�f~� �
Y����v���헺���\�M�s)��?�����ӊ}f@�q�W�4��R�2�~]��:?F
gFxR�+�C]�|�O�Jw��	v�x���cF'LC�He���y�����eI5;s�]]�'��h�G�?���%!�9�)�!�����(1�o��g#���gv$8��������6��j=[�c
yR��b3�����HL�P[4Nb��⨞i���'p����%Ak�p�Y�9�1g��t��t8�хT$�>����77⯾f���6�`��z�A���"��d������ƨ�� q5F�[%��%�؛3���z����\b|�`�nIH��vfk#(�Q�VW˨�%��)�@�d�X$��6S��������1&�0:^Ԣ��o�	9�eq' 2U�jW�A��8.�,�j����N��'�f���{p}��u=t��rN��a�.��H�(�˱
1�{��ĝN��~�I���n�\N+��y�2�ab�4�hPO��t�Z��{M���O������u����y��X�D�����P�^�x���D��->��#3?���  m�th�xE6G��8?z�g���=��'���,��2��^�^�(�`� 6aF�P�r��c��N)�^����i�����c��Ao!ę�\W�֩)b.!����6�Z: Z��ʱ�2��.�[�������H����.ʗ�Z� �x%�~��u������͌ВM��	�G�>��i7��ŧF�|�ޞTsN�&I���&E�Y:����F�Xd�W0t¡GИ���]hй%�^X���Pww�~.�[�V���TY��������AR::A��o�~��Q��{����^�j��h��������G����J����&�"y[݂��>]��?*�����i�>�f�2?�]<z�d���E_�-4Yd�t��je<T�������N��k`�bF�YpB�=�4��Σl�N�)[�r���p���yH�h\��HG��u3���,_=�m����$)�
p�RK �|2�5P	�3�̇%m'͎��B�]�2sߵ�=	9��������w�_��0����������Ĳ>e�:�g�r���ݬ������j�!>�'6$�<4gb� �~��05���c!��� }�%��(�L�u�����.�5S#��I�RZB��-�)��:���Z7[x����`�)��t��fL���]f#`�%�Ӯ��&�7�����S�Փ�T�]B|��z��J�Nӿ߿N�e&\$�2����euܐ5���H�?�/U�"|Y�l��t*7g��s״�{�z.��"��S��D"�ԃ��{�[{,~��N��PO^�8�!��>�
�ʎ�2��4��ٔ-��~�e&��JB��۰����W�,����E����3�r�wx���#[�3���"��'� �{�(���~%l���8��ҺTh#�nUZF?�c��!vV���>�\��$�9�ұ�|K�i�8�D�����d,\��!��3.>	1Iڏ��}�n:��禬�F���D,����za�.rQ�rZ�N OKZ:8�Dʀ�
���������'�q���	��T�KH��\G&�q�?��M;6�	��i!W�@r�VI�ov��/�j?�����^�A���uI��$*O����&��s��z�:<�]`)h���_�~�۫
��r���B*mN(=G���k��%��&��)��EG/�:����T��
�ۿzl
D2+�( "N0�Y��öb�Fޙyj�7NG�Al����pqiu	�8W.���w��q����ھ�;��@�©$��:�q;��4_�=�����d��\�v�C�>A�p����/�"���M��c�h���&�|���H��L
�VċFC�CsRZ�"�4N<��|����*���u�32φn�����S}$p{Z�H���x��3��0/z��}�ӊ?�W�m"ݬ��$X� }9YJ3��@(�'_�����f�� �<s�8�^C�#�u:��\��* V�PL��S��e\�Q�j9szs����B��o�$�< �J���_N����@Y �%c=�/CU����5�kOŋC��Uj*-̚�݄AW���g-�~bl�\Ii1�w�������ԝ2�?�%��bF�	T�)�Pn�A����%[드���� ��R�:w�i98�o�-�h*�{�`��͢z=g���MH����Eݍ�	�Wj�S\J��"4�8� z  *�WW����&D��"]���, �tj0�e���6�O_9�P�k`�Ȅ�.vS9�b�T�\<�֠�6��ѱ�/�(u�s�Y��������=�6�i~R����,�,�37������L�6�Ұ0-`�P�4��P�5��6OFj�,En1�9e&���H�g��@Ou�[s�޶r�^���0�ɑ6�l/a�2�"��N��;e 3�|f�D� �}}XxX��"�G!�aI�Ҹ�B.!&�,�U?��+�p�!1���bN/���U6p�ͽ�ա&
]S�iq����2�8��#�`�e��{.���T��M�Y�t�"��,�q�HbF�EcXb�H;upB��2ϑ)Ʌ2ބ,��"���w�ݗ#�%!UɌ� S���}SH���Z�g��UC;	2k{�<�u��X�61ѯ}����i����op[�&:�T�;�#KQ([�����]��I�rJ/{A-��> ad���\쇄�O����9MB5�d?�}~Qm��P�����G�N�=A)X3$&dS��g$O}�
��І���[U0�*��Y� �#o���'����6�F1�?�udȻ��2�.�4�o \��L��G{���f��o����d^�"p=�)�����f��(_��P)�%�$D�˘��'�e��i�R��|b.�š���#[�I����)'w�"?4$	BF�	Ύ<��h +ȉ���-���,��B �/�M�b~�nvL�Z� �ߣ���Eh�<k�E�e��'QjT2tA�����qԑ��7�n���?���c<�K�z2g�)�+�����cn��}�/����'�D4eJ�g{���?�7��%��V[,-�r�i����a�@���,��/�]�O����a5�]�[��=3En�;^*�/����T��8&T�[�R�.!	(f���~���<E挞P�-�h5��O�))j�Ғf����s{�'
�t�f�*��k�#����/�6>��Me�l�F[�q ��8	�?�=��Z�p��:���5��=�.YК=mY�r:�}eZ�ϝo��Kӳ�L�"�R2���0�L:E�:3!wƷ!�P��n� ��NyW=�ߚ�
=`��X�� lWH@Ey�k)��=TSS)3�1�O��.�kQh�Sh{������,�6bb��@�MB�D�~��Q΍���1��XB"3T^��b�3�^3��u�>�I���>/G���1d�h]o�{����ȌRH�zY�fE]�ٌ-���ɶ��~�]"2S>q\��	�D{��\噹UdY�+��q�"��d��=,�<W,��Gn��c_�=������fv�\R�k�3P���Р�g&�"�l2�d1�o� ����j�4�lF�rP�"�(��Ic�k�9�:3_Ҙ�mr�H�����e����GXZM}ͦ45ލ�/�M��F��Eg#/VZB��,�����P{�g�˙���>o��`I(+�O3t���Z��d,ԧQ�'��m�r��B������H$G����c���l'�q��0y3T}L��i��g=S1�-10��"�_h�*�F����#$V����k�,�X�P�bkyT����X�63���/�e�iz9����z��-(�G��%�*��䞒)��� ʄ�:�~j�U�w�T�v+�����@^�&���+���E�4��o�|ټ�8[����7Q����pP�)� ��O}[d�O��S&�C�BV���,	1�d$��v�_� ��;^df����K;K�����K���jO�����ù�6Ä��S*Sġ��7$A�Œ����ho�P�R�j.������#O����p�4�]2�D3��ѐ�����X�i��5ϱȋ�b
������������\�      �   �   x�u�A�0����^ �(ʎ@Ѝnp�)�6�����z�a��I������%�N�Je��*ו*�z��lz���ǁ�9��̳�3����eQ��vnZ�-�`X;�3����]$�|�8���d)q�D�xU���wy�pu�r�֧��@���li�ȼ���}�$�\Tk�      �      x��\�v9�\g}��M������zX�(�eW�g6�L�	23�B&(�_?q�����00�n�� ��7�����A�O��o�H�Iz~>:;Oφ��|��WZ��&��J�qz�����u%�χ'1yr����O~Z$����LN?~��K�.f!Iv�	 �8����&y~��IrY5R���0���rc��6��_d8�;�Fv�&R�]�[��0Sĝ��=e|�+���+C�N���R��o�xr4� �
!����:iKo%�IC෮e��
�������A��(޴�a1�����^��>y��&��@p^�Ǜ&x�p���tpSDqc|������;L�
"�]y�����!�ۭ�#���������G'�[�fiK<�>;�Z�Xߚ��;��3��E����`�I����m���%� �׶]������*]���ӀB+��&)�OS�9��܅vi��t��i�&����?_���6��t0� �����cឃӰ
���זHʡ����<����3�����8=Z��O�bC��3��X�&F �Ӧ]%)�ɅB� �� l^���|\��*Djȹ"��tֳBR��BȐ)\��4�L���h������'��wA�&�P~�u���tJ)�K�QI�+��3u29�������y��:��Q�{��t�)�}/ȣ��里���B����x)���B7�.+Ta��iP���8�MD��C��h����<�'�r05��i�X��Q�V��HW'GT;���ţ��tZ�_I�Xi�*��f������?����"�o�,V��>U��j��\�����B!��;�+�I ���aqضk���}�m����4�H�l{�\`	h��_�v��N�d�O��튅����C��1xu2�n��3�u�n�<��	���A�����T����*Gf��Z�7�K̖�a�ޛvxr��� �1Q��כn�5�$="�$#-�^o[8K� ��-71]1�a�I��	�ǝi��I���\��<$����Ja/���d	 �x��^���Z�[Q?q%[�Vs���f�R:Zl��� ��Z�o^������v�J��mM�1�(�B��S_�f�R���������a!��9�|`b)`�Ж�!��v=\�e��e���a� �wX��M�!�Ue�!�f�ueeo��a^�YM<#b!O�� �ol[�*��uT[� x(D[Xh ��CI������.b��
�am��w����(��ᑮl(�<�o:�N�.H��o���X�<�;L�z��^��z�-�$da�� K���8�m,Ua�ܟ�6�R�a�|�L�Q����oܒ��OA}�'#l�U��@�_FP��2�f�����[V3���!����!� r�i3=����-B�_��nk�.)X��@�x� ^�/�� 8�k�Ga}m2�C�frq�wQy�-��C���J6(�l��V����?��U��k���)��ơ���\Z����?Z��8��v��k0]��Xu��\�!��Ӆz!p���_�p���1�>�5���(�g��7מ]�����ԃ˺wɐ���[̤�.~a
ztmIN0�7�QIҷ�Hnc�yd��4�Z��}�ܴ]eix�_���6N(K7�Yʳ4uӽ�v�,,��n���L�=�񦇟�hT�#��=Ќ	p
��VD��50Nna!���j����d!%�*��m�תnf���"-_	"�ކdhd���6�� �'$�!QoÞ3�y��!����l|����Ҵ����"� @�_�L�AN2H)y{̡�r��޼����ٮyn�G��d�5�C���*���:�pnLDAN~�x��̋�6Bt%����܃hoL�-��H+�9 ]ײ�E����aM�nq�La���Ǣ5]�7~��~�U9�؝�P�����N�z���<��T/P��x'ui#�)¾�/j�.�t����+�6���@��Ċ�z'M�����J���6RX�;kK_;Em���]�N8wv%(�S�A�L
Yxg����`y1�ϖ�rݹ�X]�%;~)���U��97�X$>b/SXǻ�.�P�\��8�����.,j{i��y�O!��� ��΍�7�C���w���C��ǁ�І%]bH1��,�Gz�w��|l�-�{��F�Q
��e�AL�/��,��O_P�-Y��_�����KkV5K�)����UI��'_:� �46� ��0�v�����{���# ��X!}b̀�Ch�i"��^�ޠ�$?���#3�vOS 6�EI�Ja������4�,���w�R�#��I���y��]M��@�������g���o�����,�{�|oj�w�i������R��{�.u%��
���h�Ja���)L�+�ؘ���zҚ�Zs��w�5=)�=,��!��j���>��w����: �n`��=h�=�q28�h�a�9�n��=�"���e���AJ<�f����A���:�`�0tl�|i��)��k�)����&�vq��
�W+h--��l�J[w��� ��D��:��Dp`�k#e���6��������H<���)���;H�H��mDn�0��7x^�֑g�`���p��Y_�=�Q�a -�4٢o�P{@�t�|�Ȅ;|�dڹ�W������v�	IA�����G�(�=|���t��[�n�ު£�����@C�?����j
�L-t���j��}��v���z2�;�ّ��e�f'�DwN�@y/՞kKQh²�L����Ch�q-�dMa�
�d#Z ��+�b�H�*>�w]g�'S̄g[DE�ҳ����RB|�T�;����S=������_8W�M���Ne������1��7%��)��TB���ͧ���<"�m��pz\\
vmcB�pjbkf������re�]�`���t&4�A^�8���2p3�f+ka�����p�xVAm�$N�;��N��\9_[�0��6�U3dʩ�9�����tP�nOہ9�:0�������<n�3�p�A�(�NՁ�LUd�X@h�9�����6���/mf���p��qe���R���p�|���6Y!V�AB���*	���Q�&���S|-b�y"C<?ꡯ:�u}�d��Pav��tBY*ۄ$�h[۰ŝ>��Y�pt?-C���ȣ�l�u�G�dwJ�\�NLY�L�Ҡ����,S�aI+�⣱���F��4�����ˑ��>�_v	�;r��5+����+i<[��0t��)(�nM=vg��V�^�]2d�]���]iz�
î]�nG}V��|D����uK�N�8�('3��1l�7ǵy�
(F�0~�;z�����Z�=B[��ػ��wӚ�k�����u�r��a�Y��}缡��)|������6̠�������^M��4��$���`���$+Q�ɺU�Ąq{�������D�R*@��I���$x���x�uº4�\����
�]r�2)�mƊ�H�n���a����Ҩl$i����6��d��O� U�z�w==��>U2x��3��	��5i"b����,�.���`r(U�"��>����0�H���B�$9k��3fp��K�Bo�'n^ÞW)(����5��[H�PV�7�$�*� ���+|��6����>��JX&)�~���� �.�d ���k:�9����d�ua �[�Xx@�8����0a��ܡ�z.�X���^τ�T�4�����ZC��]� ����3�ߟ���d}~�@�=�#���	]�ϐBf"��f&�*,�{,s��m�io&���7=M��`3��V��w�E6)y���!_l����Lc4g�5�7�A38����m��g��q��C�� �JM��r�@@�t�L~���a�'�	I73�ԑϑDf��}3z��v��k���&pVa~fFk�锚�bV�bV:G>��A��E�Gr��Y��r����wm o  `g�v�]���� �z���~�;n�_I���������5���|���̻���Z+z!�-��2lc��X�ag���+�(͂o�`&��������S��9S�vd��J�&�s�įP8���h��߿���]B��_����%�"y�M͙D�z�ulJ��o�p��v)�@o�`D1�	����Y��u�*U{�b�@O��Y ��bU�d��'���C/9�[�m%���/��]~`����AdJ�#��޴�-�&�;�3�k+ �*v�.Gj��v-�rÏ��ls������r�ŹضL]�����;ӣ�(�d�5��u�၏���5�sT��]B�鑂Pc�P���9������
�R���V|�;���z�	�U�;���M��:6Y�΋�~߻�7�Z�ǯ�현^�wBX�������y��5Փ��N��E~�=Z�ܦo� ������j����=���מ�u�_&��~K9���:a�./��:�:���c�P�z_�(�|t�ߨQ������r��q�0̗m��[��C���P�HG�3�<��t`��%Ց�{%kZ�`E��oC��fW��3���gf�Y��(XQ��wC����8~�������
1���f�oe7���1�� 5����@���u���:�vz㈗<�yy��*�Ð�����[9�Ï�m�Y���w<��\� A�m��ݺ�Z�a0�Г�Qޑ��Q�cDO]�p�s�A��sX���nJvu8�C�7�6��(�s�w.>���+�t���?5JA��|��k���m�&�!�rS!��õΝwK�?��úΝ�ȭ.?尯s:��	�W ��Cn�f���}Ɉ�Τ����<s���H;��n�W28
�ou�����{-?���x�-x�yo�?���+0�=$]�wr�<,�a74
|qlhF/Ёy��U�;�,, ����u
��yh�����d�l0R̞N��yڕX8�^W�q�6�v��ȥ�6v|�W��|���;��o2����h)t��oS;?lL�f*��U!���}���
�(0�@x{`����"l��&�U���{� ���0��b*�
��W����T�pP�z�����P���FC��W5A�+�E�̶���"Uj���D��2�X��E�ܶzj�-����;@�J��e�J���VE���>$�.�bmӉ�{9\�Y�� �I}�Ⱦ��ݙ��������G��
��W���<��K}��',�T j��
H�W��_�a��X���v�
�R�Ԗ{����yϯ�0��.Ԗ�H�@M#Gd
���Νb@���0��=�v��@�:p��]�ZU�qp\+�Bz��@z|�/�=[;,���2z
����kh�����?ĺ
�ͮ1��/X�D~��D�S�9~������w
��o�lh@�*~�\�6gs���۸����[���M�\>���9O�KIA�
��;*��R�ŞTA�q���3q���g��۪Rn�֗���e�.��Ai����p���J+��'�m:�;
���vi�٦[=QM`c�ֲG �<F���[���U�<$P�EB/���!��6�x��G��ͭ��z�^�9�(Zw���0�-�eP`��a��۾3��ʏ�ws��SQ�;Mp���͋7n�8�#��`0w�m[]����"�;%��i �O���L����!�0�5��x
 \Л�$�!��0��T��E�CodD2
D`V�3���7�u��m�pd{�#zy�@��[gZ�(&�=X�kʹ2��Oq��l�OٺX���)Z�o.����Z�8+�V��Vz\�l0�?�N�H�駅BՈ��i���o���?�I|      �   �  x�}�Ms�6���_�c;�x��#7ٱױ�1m�$��Z�IT$�����w��=a{�4z^�����z�4z�h ��(���LD�(>	q��j���9�&�k4I����
X�ގq(���V�W�k��I&�Va�G�7�8CS��r/��f'M����aӏةy�+r8S#�0�qgv�o\����%�`���
���#���qz�Ǜ�+g-�A�`_��p>`g1=�8�Ș!+�܎vzab�$q���qP�g5ٵC��Ƀچ��~���̝K8?���8��ೝ�9���+k�X쬋�.�����N���-g�<�?h��x��J��M�^�å6��.�u��rIT:����y\y�.���ި���+dj^Õr�}7p�b�,đ��,R�B�%�R�oϋY蹞kO�x�������>���� �/�P��c.
�6\�r��?���k���Z؏8��zv��դh���X
���=e
7x��bd7�����Mء�'�,�+z�>J	_5��Wf��)Ҳ$�r�$+��:���x�ʚ#��V6G��W)�V��k�)�ڱ�o�⌰�knuN��$Ϗπ���=���Z)��qX�b�0eE����KLY�d�|W��_�����J��u~�Ts������8���7��S���㾯
�W��T��VS��%%P��^Up��6y��Q��`'ֹU�h�Cׂ�L�4ɥ���	9e
-�8>y�T��B^�dB��Z<��:�u����!W��ZeTϸ�.���n���2��uC��_o���vˍqu���W4fum�5��/C�hw�~�I\��#�w���9�h
xP�W��Hm�Y\�#��\ME�mT<9��H��M��!���J����2^�kW*Rx2ګ���b��bƌ����7����Y�.;vx�b<�mA1/.���7�ݧ$�zmާ���i{ʈ+��&�C���[�-]�}S|�g��NONN�rD*      �      x��}�r㸲�3�+�6(�|�Ʒ��ʮ��]�'�a�Ej�b����k��>ɉ���X쨄Lb	`e�|�������������<��6l�2,������u�r�ى������_'�M2iNf�:��kz��&�e������싛�1��9��mѭ�V��ES�k�:���k�eܷz]�u�v���h=�Z{�I�E���(�"l[W�� 5�gV����eh��ϯb�	�o���b�=�_~Sa�_6��r��X�n�*��[���56�:��{��5��9KF�냼i�b��������}*|S�� _td�L�V��bZ~�JXӹ��n"~7����gf��[����[�K8�u��}G�����'���6��*��M)ȇ���l���?B��߾���u��T�f��;����+������KH�n��D�]wp?�E�m�G[�lf�4������4B�5�_���������dv�A�2҉��H�>5����bU~�^y��y�S3K'��Uh��݆���T�f��;���^���^�k�%~���,�w(�]�����zQpUj�}3`�3O�\N����2��24��_����*�zz8Ou��^�P	,����|��86��v�q/þEۗh���\���ߋ�"6����6�*[�f�N��븨��r#�R�����͌��E�m�e���,eI%���,5�vL� Feє��.J�8mB> ���l�w8qW��[Q�]���-� պ��S���*��ZbSa=�p����@�������ZY���l�b����:úz)��H�Ϻs"�'R���:[/�2��^�VF:Z�U��;�;���N|.y�2����Qhf��|���������5	�H�n槼����hVE%��2���W��}3?g��2�u	�9�����l23Ggg��l1�/f��_���%33���n-o��>B)ceK�WV{0�tv�fGY5~D:�9���c��ٙaM��0H��N^M �K"պ�����.�֡*����R�ɾ#=R�13U����*��˄�H�nfl�^��o��#6]��'p>�D�žg͆�Yt/}S;��;ն��ٜ��l�1�;�T�� U�f�f�|��,xCWa�[�;/��d4�G걄��x���ݍl�����������\��e����{�Z��>��Z5�7�*��>,�����������~d>��޵x�|K��9�_&�Z73x_���v���� �&�Z7�v��[_ʘ���L�ȷ	��ͼ�ϸ�t��$��zl873vƾ���_�N�uD2! ����LXs�k��s�G���6W횹*�o�n�G@Wu�q+�e��������9<���IX^�*T.�mR���97�E1z���ʏ�(�fnα�^Ɉ8��ov���@~K�Z7s�oQ�8������ T��y:��4�>�Q����Y���3GO��Z޻�YMe�7�d[�l��)�yѮ�V�d���P���'�ۏO�^�,=�g���q<~U��	M�~�v��<���|����jL㮑�_��Z�� s�*�L�?a��m?f����S��߅4�"�,� �����<?��Dq��t�Y�֍�s���zz���Av �y��GP9tf�������d"ۂ���o��3Sϰ�����ۘ�7���j���3��/��^{����n쭛Yz6��;�}.Y%Z�H�U�f~�e��T�0)͜�sh���k�8����Ng�������gf����6Qf��d-��;��+&�%�Y����J��޺,w�m3O���{Y��Ϻ����j���3����p�+��Hֹf�����/'����̹-�F�,d��m����n%k2����3��:�nh��9�e:��9`-�l�9����`f�^��=X�-VlJB���j���/�p���us�2�֍��/f�~���0�P���<L(Ķj���/i]���%����Z	��ؗ�~�xnf���?yt��a����dw�j�U��\�O����D~M�Z7s�����
�Lb���_	T�fƞcU}�yA���V���F��IG��`��9�Tk�]�.�Ki�۪e3[Ϲ��x.��Z�D?�M@�m��9x��>�ּu_�n��+�j���s��?�f��0�u��,R��f�������AjsU�v �	 ��͌=?N2��(�/.�<�>�.~0S��,M7§��m�	G��$��7���k+,�8���k��~bqU��.�J8�7��<�U}������:���Oh ���^�݅p��mݶ]�p�E�1�V�p��C�o#N��Į~8��z��.�B)�/-B��ɉ]�p2�qI���y٘�V��j���� N@ڧ���J���6�6��m�u'�Z��=�2�e`�|; ݾ]q�^�%�g(�Rt˴F��EEv��	}�&U���ں��s�G�]���9q/�蜹M�e�e��l�eF���Ei���t�v�NN�D���J6�2��v	�7B��O(��ث�lc���GY��Э�9;����o�CU�9f�H�og-eKWE��ע��������|�lI��}.�+�}D[�m�+�K?#~y.���K#��'�K0��b����X������ֳs�"���=,�
e.��n��=�9;g�[���HQ�R�U;_)`z^s�#����C�Ԏ�E&v�$ɘ廼�����p-��[���ouwk�zn�ȇ{;b���Q�Įb�P��"�{�2��q�G�&v�$��������Dn�ۄ�k�zvS�-_Zl�ʲ�g���Yl�3��1���/E�/.�)�ݲ���S�!3��	ՁP�U؞��'�ГS�tS��.�c揄��{��튦�tL�:Ż��&�u��X�����yZ���cMYÒ���1Y�Įi�P�t%3rY�F_���8>��y5ڋ�˔7=�Uk�rӺ-�_���,�a�iy;zՄ=�e�e.MX���anwe���t+�Vw	�hM?<��UOx���C��A~���BZ�]�*L�ӷ>Tp�X���,�,������d�n�K�'����,���O�gS�qj,�DC�7	�=�YL��]��'̒�h�K�F��M슧	%O���.��cіmwoW<�5N ��UO-��;�x�wng+�N�2��p!b�����v�f#t�}q
�~��n��Ҍ�Ǳ��VX��"q�t��P���PS��{%u��u�v�R�t�/����7ke�~M��`gjvJ��w<oh��+��]˄8���?�2L3|p������yJI�MCU7\�d5'��[��4O����ڸ���H�o����5�����!���п�]��)�l�`�1Ƞw��t�v�R�	�s�RA5�\��v;w������RF���	�*a�;��聆��}��qH56�>���ھWq���7՘�{bW;M(w����~�ͪ���u�jv�ӄ§k��"��F�����	��iB��߱I~�sWK'��\�ރ��A}��.�yu�&��Э�9|
�4E��Jv+��t�v֞b����/��.cß�:>�������~2�vK�S�T�:&O��UPʠ�(y��P��n��ۄt�v�&�|�� ��H�'V��y'�aϸ[G�>�'����|"�L�?T���S)M��#�߮�����6�'�Eld�o��@�n�/�QOq��K�,5~1v}>�k�&E	��اt�y۷������E<�	gPFGw���VfЄ} ���s�lB�k���V�y���X��R�J
���@R�<�]$�b�Gޓ��g�3�y9c8���;�+��"����5�����4w ��kt����")|�8���L
"_�FoەRx��06�ij�w{F���j��Y��V\Y�e�Y�p�Xk�#�v�^&C�y5��!�3�ʷD�};�)�����D�9n��#��]9��(��ݖ,�E��c�����;�Lx�Q@ȡ���_��n��\���ě��
���.�2���v�^�����$������ߌ͚v�^nYޡx�    ��ζo��3~�f
/o2l9\��NF��a�Į��P<%�iY�ֿ�-��K�'v�^ 6������ʦzl��Sx�7e��E�m��N1��7�'z?v�R<%^�̑��_���O0��'z?v�RH�ﺤ��g���C�~O��`���d��������
N���ԙfWT�Ŧ��$ާ���X���އ���)UEW�[Y��n�x/;;�+��J�>T��Z˫�p���P�����9OS��P��bۺ�p�3����iʫ.pgw�C��n�ۚ��]V5���?*�]�E��e;�Ͽ�>�-�:\�@u�>[L�b�	�T�H䃨�MY�l�[����?��℉x8#�|D�c�*캪)uU�M�2�w �J�[�g�8�j��n{aR3֖���X�Þ����? b��0���]{�����۸ev��z[�ctR���@�Ş��{ߛ�a��l]d���n۞��ʪyɅ�	��*���	�����)uU��44}�\恲�q~�'�7�'z?�TW��K����J]~��nݞ��
���:��;(: Lɻ��Ԯ��Ri%�I�m��p�dST���S��j:I��a)��C]ug@[�'~���ޏ��T[ɞW��c������{��xB�$N8��ܠ��!��7���3zFOQY))���� %��bN��+��!ULt���)UL� ݺ���^�]�U�C<�x��[ վ]w��)���o.�v]�OZ� Эۙ<N��{X.�N��ߢ�[��xr�F(^�]
��a@�.{���Q��7�_��!����!=�{��ګ�4vR�9�8|���zo��R��uL'ew�j#ҁ���5�ރ���ِ�;����m�\����~"�J=F�8��n�6N�?FҐ�YL��E�ڲA~ǉD��k"ݾ��L(��[ y���-���З�j��*5=����kq�7��	��l��Df�)<��|�HKv�<�Iط	�}�yM�K�¿������t�v^�NRj�c�F���+6u�v.����3�@�z��%B�>��`g2�WWu�W��d�ȡ�O�7�>�nƴ��U!�-Ӕ�)��]w5���>G�X�D���k?�JtjW`�EN�r'�j�F��� �u;g�I��;�k�ز��8�1ڵWS&�z	�Ho��r�[�V�������G�W��ڪ�\E���	���Wx���OaR�P�m�¤�t�v�fC8/�矱\2q1��=�n�����wB�B6݌�\Ȟ{,$sjUb��1��dҹ�M��}�[�� P���ۤ�:�[2�op�	b-��m"�c�Tn52��*I�kd���3���몖�����:dFK���=�ԮŚfkq�� /����+�	�욬)L=w�����U�\e��m�t�v�R��De�+���د.��zv�2��u/=�ؒ�5�t�u�v���z����:�ʖn��X*�x���q/�y�%�H�o_k�S�k]�����S>�l0��e��^��ČY86�LH������_�X�_�����
 ݺ�YL6�'���������Ӯ��k�o_ĒwJ�{�/M ݾ�U�_�p���L���7A�;���z84��q�4���5A��O0���B�o��:YQr7����J��i�V�I���������N��`��i�>#���<4������C0�룦�_=��=0~>�"hL�?����RS*��R��zGy�H��nL]1�+���c@T>Ȳ�:"�Y�ʨ���X3 S+Dߍ)��vuԔ�~`=�É���e��n���ӡ ����y�����\�u�ڨ鐒
��v�8HK�k��i�.jS�w�=��ky|���ѻ/�*jJ��}kw%NT�ʜ�~ɶn��س�_U�K������4u�F��|���`,s�m��t�v�2գ�]�w_���/�=��ʄT?B�-��
*�o�{��i��Ɣ,Ivptcʖ4���+���[]6�J��ޑ8���w=*bjWCM����\�jU��?\-��%�[��Z���i0�����ѓ/�&
�j�D#�֑)rB�&��`g.UW�( ���a���������)W������ES�a�kݺ}��2V�/��+ʁw�#��6j�dU_c
�x�;���}K��`�0�W����|U�V�������롐���=�>�����o��a�J�s��v���x���m��'�
P���BR0;����������R�uY3�	��-TZ�~�]5��
��K54x1������ݸ]�������?l����\��;���z����Q����"}v�k��La�@���;p�˄t�vSk��Bw�a�"Э��K�&��ú���P �t�v�8E���C�&�2/w�؟�uP�DSƕR�+�{�6ʌ�~�̮���rS��c�2S�!���x{���hz�U�	UV)��mJ����~E�[�� a�*��Wq�ڽ�k9����>�@N&�WC"]�~��R����IX��^�y�eb�#���*=�9����+��̎w��x=3Q!�bn�j���gz_��!'#�d�.o� �n�e�>����]5cf�A�AB�� h�*X�î����V�	��{-��vS���o�z/�
"')9Zx��ҵ�7]W1���f)�U*
w��v�T-�HG�����>�ϖ���p��'𹖪�8�k�f�"��%��L9��O
�۷3�%���B���Oi}��n���I:{n62X����ql|3 ݾ���uu�r,=�u*'�ot�vSu5ܮ�����H�og1�VLQ!��m-Y�6	��ڃ��ތ�����(P9�L68I�8�쪨5W��GZ\��ݺ���\]��������]���J`WEͨ�zJ#�g,*��p��t�v�RuuQɄSQ��� W���'*t1�z|/*��q'���~�^jf�B͘���$AWQ�
���}��;�wS����)A`��W�3�:�[,�W����~Q���
�V/Ŗ%S/��%�#��3��i�,WX��,.�Ch�n��Wf��8&Y7��K@�P���Y*����W��>�ͽ%���0b��[��c�beWu5�A� V�P���\�Je�Ü	��9�����B��ѩF���D����zS79�����s�%��C��`g�P�o�CJ��; ݺ����_8��~�~��5�x���;���:��=����,:����C���{����>$�m�RTs��>Qw�:�o���������m4g��5����ƁVޜ2���׮��Qc�n�RJ}���R^��>�,��*�q߸q��ۡ���W�zvg�	�C��1�r��b53�jF��.F�p�քCEa}WaWCͨ�:Jn���� �I^u�v&3�U�z�یj�b&e�;���ޏ��Iu!��	!9�a�pf�Cͨ���a�Iލb&����5Q3��b��s(�v�c/зG��`�r��~�JF���k�}#�Y�M���O�~�
�ELeA��[1a$�۷�����?FrBt86��
��Ao��b�j[���n���!���+�P�S���H�o�0�W�d���u~������
����~?�{�D%܌�!��cU�'`�Q���"�kFV�o�bg!�uR��R��UX3��R�$H���!U��HQc;�穴2>?�Z�a��,K��^��+|f��cI�p�GnAX��������#�(ȏ1m�{����B�[K(�Jq�J	�=���B����1KU5;���f,�2��by�S�jx����3c���5�E�B��F�(ۺm;{�ĺ��8V����v1`h�F�mgv5֌j�˦G�Tr4n��<�iv=������FB2f� ��~����X3�P��q˵C�m����]�5������Zs�F2l���f�i?sD�N��1G|q��.�k��?�n��Hd�;ݺ���`�3<�Ǻg�y�t�v��0 �=e�Ynb�!O>e��އ��g�ˎQ�S�1)ʈm;W��J�wq{�a�t!�
P:�ރ���a]ȆB܆X.d��o�Vm�X3*��� +L�=����yz��    G���h\*>��7���]�5c���~� ������E>������{6dj/��#�5h�$���}�Y���zO�M�����_$��a�2�XP��^�F��S�"��=��LMV�ہ�w�@*ہ�w3���f�e����+ϴ��#���]�5c	���x<�s��	"����]�5�"k(n�L�n(m�<Ъu�kF-�K���s�4|7r>cWaͨ�B�z
�<���+$��ag1K&n0� �x1�ǝ��X3�.dw뾇5r
�vk#-ݮ��T`![x��5����!Э��J�2��_�(�����#5Rfv֌
�g���K�kQ�|8_��dW`͆B���U�q/�#�K"ݾ���`�^E�b1#(�K��`g,K	B�S�K�슊����;"�~f�b͘���b(%�i���<�]�5��[����V�A��,<@�;o�ƺ�{Q��7�9�[�u;kχl�����AC��/FN2�+c�+������<�[P���݌Z,d�aƥP}f�a�% ݾ��uX�pi��l/���=�+�2�z(6�t�\x�0���]c�Qcu���l��
��C���3_3ꭨ8�SF}���ez��_���3��*;r䬙9�:��|:�k�t�F���1��5ęO�[����2�f@�}3s3j�B��>-�[B��Ys3��*;I���bި�����q,�BfW[eT[AG6�Ӧ�#_4��(�+�2f��QS�(]4���!�iF��3��*���5�.��u���WݘٕW�$)7�O����!�{�̮��&){�x#U��öc�>�Tb�;�Yiy*���e!�A�w�u{&*|���@F�Ǵ�zK��Fw\�]w����K�e��`�>���,�5�B�:DZ>�6$�k��I�K���G&K~��n����I�ũȕ�r5�F�d��-�k�2j��cd��"FV�����*���!�`��<�[>`���b�]e�QeuQ�h!M��C!.��ag-�V���<����������팝���R����-e?�|�ڷ����p���u��3��ҍ�0dv�U6v�}�vHiBހ��NX���\���b���M�k�u�~C��`���x�����]`�=>?z1���5X5X($pW��$9�5Z�];�YU��	ǡ��qM]��#�{�3�
��|_0s�z؂Y�tؕW�,�5�.fN�y�Κv�U���9���- #��t�vֲ��S�X;h�R�(���
��
���>@ڰc;ܗ�'ݺ���� ��� ��-��4	�*a�;_�����}�K�U^�n��ރ���Z]���6�+��������������J)wHW5>�"!��v�Rm��AD쉶��_P���\*��#�ӥ�`	�(K=�����;���?�L>ϛ"Gz%�{���H���lf�B�7Yp�
�����d�Y'��`gw6���D�k�;dK .bFT|�]���7E��:�;�M�-�F�o�3��v�( {Y�b�FN���M�]��1��C��2"�!҂ɋ����D���t*�����]@�U��ݺ��I%+�S�X�k}�bY�a��ʫ,)���{�������]s�Qs%k��q3(V�=r+���V�<U+����"��K"J2�>���U�U��!Mn1�a�FY;6��5V�<�9W�����&�~,�=�k�2j���1QV����N9��a_���
jw���_��[���٭�KTP����+���4u�v>�����큹l�G���E
�n���ӓ�LR歶+�<��9mݶ��CN�&nP�t˃ˁP�H�o�(�Z���]�.UO�m�zv�RIu��c��zyB~W�d���j��j�oIA�wH|A(2=vRkWR�cM�W��[*)^90Wh���*�,U����>Qƍ�c�'�]?�����Gd��Pqz���۹JՋ�W���d�X��9g��VT?#��=���->߈Wl�Pe�b5���֋���J�@�۷���{�=�C<R;ޏ�o��*c&+D�`�gmQic��M�+�2��V#��%B��q�� ���~�:)�!Hgy�<ɕW���3�
�ǘ7ܑ�]��i@�H��:��:�k��Xn��i��G��<hY$��a��Y�BaQ���Y��9W�+�2*����8���h�r,�'��2��O@*��lm��~$ ���jWLeTL]Ո_����qK �&Э��e¸�;�5k"�$��v}v�TƊ��ΏZ�WM�cZ�&�,D����VJvM�����k�T���3��n�Je_R�",H���R���]U�ev�TF��Uy�qֵ(�	�w�u�N*�N
wJ�%�x�N�wa4�yf�Ke�K�E*���㯎����~?����)�F"�cłl$�b�؊e�Le�L�6ALA�d+�3A@�%�{��7����,�__!�ef�t�v��O�M��׿x��z�z��̮�ʨ���^�72�Ȥ	�7 �u��K��e�[ջ��/� N�e�쪩��)��I�ݐ J& ݺ��TL1�dǶM�h�%;ꊲ�]/�1w��b��ؓthz�����eu�c-��2����|K��`g,�R�P*?�jQ7HR�l�	���|e�*�"����{!��mݶ��sf�J����}/xB��o��>�|��J�S���z�%	m��#;��]-5�Z�	.�_���u([��̜�S5uQ�pt(�Dim ���t�f��O��z#$b�Ku��/zf��S�����^\y6>,F�;�v�>gLL
ϑ%�o�t�f��OR~�Uh�v.䭋 �:��qs�Z

�
����ާ���(�55;�����P���N��(���p����J�9�R��,�D�6���-��̩��J�^�J��e��F�r�v�>���E	��l@�h�w�u�v֦�T=|��~�he�	�C[�m���?[��[�c�֔�kd�5�k��TH1χ���.e��MУ�v�ҜꨛR���QG��U���v��|��k&�cf�7���L2�k���Eu�a����o��wdD��K�cF*���K����L��e��\T��
�Sh���a�IO��<���sk�2F��g�k�[ |�[���U /d�)>�]x��� ��D�}����C��>�q��J��Հ�>�,���"gj3�bȲN����U��h�
}ߩ���������s��h>��Cʜ!Q^2]ۺm;��_�PU-�x�^��j�����n	^�T|"ǫ|�bL�9��泓�� ^N�^����� �΀�>�Jڥ�e��x@���2���ڢ9�����>�Ŷ��o�WZ��hN��PUV��0���[ ݺ�I�3n�L��j5$���z=�lnU�/2T�{��tS����r�jnWa L��Fq��7�~sC�Q&����쥞�*e�t�=���P�����f�ȱ'
�/��5���[��wv�SM�	�D�0�	D��E=�R�۵Esj�^tu̉��ьxs��hΊ|����iq�����}�zv�f<7J7�/E�`�2ݿwD�};�SM>j�#s�3��wG��a�1�JW�xm?j��Ki�W867�5D�ZS5L31 ���:�Nsf���t��+��0[�mݶ��T'}�X�f�����H�G�u�v�R��+ɊgE��Z�.������?"����92��#���ޓ����w�����ݪ? R�@�ng/��_r����_&�C��Xv��>����̛z��PG	@�n��<ŵ�r�E��˿���v�α�^3���ك�Sv��H�o����~�Zw2�m���}9`�;s�[��՛̗�8ld#A�W�zv�2/j������+�P��_%�۷s��%D�ʼ�Z� 2>���@���d��#�F�*�9/�v1!!� ݾ�����A��Tt�0wq��]t8>�{��Y���P��{��Ƽ*��h��P?1u"�Q	b��o�}�ܮ3�S��]��&��/�ߥ�n����,��p���@x�v�� T�v��<U��6�:���8΂|��n��_������%��3R�cn���Zj���1�1^��ۄ�>��=M��-�]*�6��e�K��a_��l�ﬕ�3�y.����s��h�Q�Åh�-�?�w� �  ���9{69fI@9��x%�m�����L��s���KdŇ��#n�X���b抺ĦB���-В���/�k��)O�����Fr�7��{ԣ5�v�ќ��?���/,%��+�|��n���3Vƭ�I~�C)%�! nd��UH�a�����!�K�e�~��އ�ɬ��s�J��L��	�2a�;�Sվ����@�6���
��]�4O��I�q='-H�G����T:�]4��t?�a�N��	�=ؙˬP���5n��e�=ݺ��ǌP�`/�����{���Y��C�N�K��k仨��튤y�Ŭ����� �k�v�zvS���h6�Vɮ�h�F�xV�u;{���W�!S3�GJe��o��^��e�>F�U�e���XV��H�o�.O��y`a���e�Ǣ�vM��-ukw�J��� ��06�k����HՉoފo՗tA;����`g�9�u"؈�T���y��,��Y�U�$;V�{�BF����r�����L>OQ�=�� ~zLȯ�4��v}Ҝu���Rή��)��ȯ�����N��*���h�=t��bz � �ؙ�R�"G��u�Z�
;E�zvVSŢ��Q�Բľ,��Q%���YM]�ER�_U�.$��2A�3�����?��ߏ�      �      x��}�r�F����y���	 A���ŗ>�v��v��<B$D�E: )�<1�>�U�U�u@I>s&�n�7*Y�̕k�̊���]�pSw����}S�>N��N��y?����כS�&�����ܶ�z�񰅿��|��௞�����x�����6�C����}�2i�_�]�5�U>��W���j����,[^e�~����|��-����l���쯋��^/����[W5��;����F����dz�7��|2���n����|2}P_ �Ŀn�ӿ��/�3�o��A��ۭ�p��o����]\���]{�%���u!��|��l&_���A�\�LH����� �6&��ۺ~����|����wRH:$s�����t4�ק���?�tWO�m�C}�_����z5����/�eL�5|��V��Ok�S���Q�����w�<��CT�WW���N���~�n�)�U�:�!?4�ޅ�s{����Il���MS����a�"R�,�W�b "lT��Ԓ*��51�^��������/׃��Q/[�0�l5����S���N����|8��#�_Ug�Ogܿ��6�&>��͡������O5�v:o10��ԧɧ�:Q��:@��*��/�����wG>�Lo�7�hm��j���h�٭�R��'��]����z�� *���������Ksh�չ�&���-�t�-E�>U��/���js�0���su��<L~�_���nG�0N���X�!�R��S���!q��Z�����>�:�[�P�ȁtq��U�3q����c��G��7�����?,�sl=���oo��k֏������0���/թ����n���U��K^_�7��\u��~�p��Z��ke�bOdi~�C��Y�K�5�뚟c�zM*p�J-���[�MŲV����K7t��
��;-�X��_W���R/ޏ��>�X��ap�1R6zߚý���i�T�[�|_m �/�eT�[̮��c4��M����P��?���k�F˽s���}�=	Tq�_}���x��u�6�Z݀�����ݜ�g��sȻ�xS�3���.�;ܤ⥘|���{xj����)��ˁ���}�� �B�H�5�+�|}�����[\�>�jj��#���|�� q9��8U�|v��8v�!��v;���/_�ll� ~�����]}k�ſ&������=��nگǗ����9si�p�������ͦuW��m1�ʇvl�u�`ַ:,[{�����\�v��9�L�a����*�t�v����BD�7�_/l�!��6Q1�;v�#[���u��Wwx��֝T��é�;dQ>��u���i�i�Ծ�Hw�T��o�v�{W��wi�����K$��Nߊ�yӾ�8�[��/�o̢T<ٮ4KT1�p�jKa%:�'��<����-U:��p����*�o�����[�3A�Q�D��
�ܗ�����WьǤ�e~��.�x����f�p�t�l����n�>K��N}����|X��4�!�@��������ޤ<�O�ݵgȻ�Z�[��eN�A?�v�C��G#H[.�_��[C(i�D�B��[\���
`�S���\�1lՂ��mɳ�⃺3u 1��ü���}}�V*R�4ޞ���B�=ϯ�W�<4u�iGB/)d�~�Z��K����)����Q���1UQ�㞉L���T�~�C����
7�:�Y^g.�6ۺ=�q����V��K9Љg�X��J�ϟ_������y��=x�z��x�7��l�N3tԩV���T�Г�r&��[S.�������{��S�{2�9�1��{�]u8�<3J\�<X6����Jk�w��A	��4ov߳"�ٕ���c�}f�6j9O��m����=�0��.�'�8ܓ�9�Kp���X����_��m�4�{U��K1���&p��0�ㆰ�������Ո�h\��+w�"
����|W @��J���c�4-�M((�-\D�R��x}��2�T�!y�b���5v)jl<�fM:�.�3[q/�ks�'^��{���pt�e(�἞�c���w-~_��A��Ĥ��<v��¿��9Ϸ���'����v��^ã]��I��=�<��F�Yz�3�[<`n8W�]D�p�?Y�,�zm:���m�֩�;��u��h����x��K�5{tOq�uOx��r=�$£��8 ��EC'ۛZߚ�� �س��bE�-X�u��~U�wO����.+�x}co�0�a��8���R?O�����p�k����m�ݭ~6�O�ۉ_��U�ߞ�Z-���t��P?먵j:4�P6��|�Ö�"�y����-�¶/��K��$�s����N�?#�t>�.w��en�&# �Ԗ�����}�� 镨���>lwz�%�sL�1뇤���W�6�_��"Bܨ���N�V_��?��b�� 2�!��s]c����t���/`�./*��Q6��c|2=+���!z��h�u�pr@X-�$��� ���O�)�����|5G(�	K2�o����@�1��kN� �(f�	��ݛ�Td�r̥�MU��v�&��ӈ�*��HN��ͨ���g�zu��Pb>�p�O~��{U�6�������}��7x޺��vxd���6���lt|k�T9L��G��6�-�'N��5ꘉ��s�½��ç���M�9�vl�ӭ��:z�q�$��+�E��6:��I�p�����3�֪�?6�*ő׍ۏ\!Lwl�0�0�
7�����j��H�~n��3|z'y�a,	�����ϐ�@�|��z�W�<��V�k1�%�Y澤�i!2��e�kv��݉������秴0�R`��c��:Tp���\��#���OP(��_t�jy�ʸ`<!!j�Ǫw�ʯ��L2_�^�~���>��ݚ�0Mr���.[l��|��ڿ�W#������cd[�=@��5�
����S�mf����íV*R���|�?.�����;o�9��B"G�(s���C=t�������)p"W�}�ur��Tw��p%��%�-F4pU�v���<z�hS��z<pp�k��4��e�5�� ���Ծ=a.����J=l��;������G��j���_���	x9�AX�f�3|;�?4��	�����׮�1l�+�K��!�����^[�x"g ��C{xyh194]/������MD��7�k�I�kC&�/G9֪��®Blc�\���G�v�؁V��?�芛�:�/5�P��&?��ki���{՜�:���=�+T�㶮���3�T6cCJ�X3�����֨!$U1���N��\b�f�=kB"60�>k�(�W���o��:λRAl��)��7���M�~�1Ո�P���y=z��aS9���в=��L��-���R/Z�
'@��5w�#nP�^N����#��7,�S7��}��!{k}���䗹)�_�"!j�������nH��E��=�X��O2��е��m�������\�?5�>>�����b�qi��Œ���0��_xk����\��U%�n.B��k���
�BݔӍ�`�`4T��,�d��dz��xi��5g��w� ��/�a���|v]@e��B��[��=�&�]������8U��o��ta�QQzmn�1[߇O�4-l�SĶ�KM��7��f���nj����wy]����mZ�n���]E:@K�pmX\n��rWݞ��zQ�4n,���/�֞�����{\];c����q�ê�)��gW�w�9
ު������n���Gt��W�V�}��>G�9�<����ų~�E�!V�C�>S�f��Bm�ݢb}|�9Q���N��X֒�^�Fkswh�Zگ��M')ҋ���Fk_�,��o:�i�U�x �A�dC[o����S^��yEÖg*���0g�p|JqAf[��gm�Z�I�=u�w�Я�k����n?�+s��� ���N%�G������#'RƩm����@�����[�� ��.b�'ou���ʒ    �n����O���8��/W��mGI�\��G���ucsx(=(=����ɧ��^Y�͟�wZ�Z��6�N�rdyf	���������ǽ����h+C��[<R�J��5A�\B�y�v1\�PIB��k����u8a�j�eY�Ȏ��Q��`���l��^]�w+rR��D#v�k2Y�����X2��`��n|QIA�2�#��=c�((��jWo��L~j�'��uB(%�nWJ�k}Lb����0��!8{�1�����#�hT��h�vߚ��o�c��X���qy~]\�g�H���	R�C�ze��Ջ+��=�2�u��D嚯�5���v���6�8���V�E2� Z�y58�j�;�xd�v�֏5��A]��ș����$LQ��y��~q���cε����\s�ֲWna�;�����n�$��ʸN��s�����v�����ʚ`<N�xΩ�[bTd,g�R�3��-1��qO�zu���5�r����Oc�y�����//���{��Z9D��_�����0�!�j6��â�U$(�eZj��=�×�p=�ʤRX�ԝs�]O{�܎������{��{o=ݢ��Ϳ�Z�@�K���:������ӄzC��#Ү�A����Wө��Yb��9��$��ɏթ��L����r��u�cO��2S.�?T�H�Tk�jaz�eÎ�4��w
��j��}�]��9S.C\J���=����ϒ]��kt�^C��I1�%�geD{�T�� H�|��Ua�ko�<�vs��k3p�eW�H��s�h��q�y**�7��(#��_ϡX<��ĩ�E��.�/�%��Q�+@2�&��l��X}��o�� �qi��X6����&��X�+$�V��M����Su���~���(yER��Àk���bX㸪�*[�z�ĥb��A7�
�LV�}2���2/7�љ��\C��	I��n��d���"�>���ܯ�K���nb��n*٩ڎ�M'R���*�Y��s�_�3��<茡C��|�T���Ä<ʁ��C8�RF����G��U�K2��t=ǩ>��j䔣�"ƾ>�R��-$l�-�3�&���u�X��Z��L� ���y��-� a/��j7ս�/7����x`��{vr�3g�$?(@�l�Ρ4T�}���j�OE���Jj�KQ���^z%����C�<a;�B��X��t>���!��x�i�� �NQ�0��Op�����~�����<�}[/|���>LQG#��N\.ƕ�(�F��@��1S#�x����s�M���B���!l2�clOv��h�s�~�\�]�>�����ɿi�O�J� ��~�،�1��!���׍YA�&g�~�p�i� ��m ��Q���!QA�|�pDtD�NJq��k`,}H30��߷uJg������tc:�>}�Z����G��HsH�Y_���l�6`^�Y/k��-�{}�U`U���D	��Z1K�f����sь^%��U8+û0x�N��&�}O��=�����{�"wu}�h)��M��C]�vwJ"˅ϙɶʅ�]����L�`;��Ҋ�r�=<�QM�z�e�0 �	3�E��o�Vm��ݹk��	��RR�>�P�l�1����,�2�GRVn̪\4W��.�M��ӔKRq-�L�Q�Śs���OU=J�!��<2"�7��5y?]��T�ґ v�����|���K�d���i�/�����N���;����^:��duF�r6a�UJ!mv]>���|�nj"�	Uq+����.�y�An叞�	{�VRmY�5�������~7��i�~&\�L���g��3S+�yRF��:VW�ٗ&���2��(?'Z��!�kչ"�G$㏈0�+���!~���p' �<&�4�E8����o�.��&H��%��ԕi�Z˹�XVT�n�j7aI�,��'|g�ev���؞��{�8��f�&��SFvP9���[���Q8 2cg���w�n�kI�顓�e%�<����#X�P��h$4��ƃB^n]g�ӀfM=K������]|�ƛZ��t��M��UX�:�q�Pz�ZK�̲��V����Tu��E��E]!�7��9
���0�*tY�0Ny=�ݷ}�K7�C����4A�Ի�+���L]�$��m�-�vي��%TY�k�����ݦQ�]��E�AR����*���PWU�|��e�G�
]���JЙ/뵫`jC�{"�$����P���UOM�M~=��
s�nP��TW7𔱚U>h!zj&����.%�uô�>?�i�y��u:Fda"&l�&J�]͌K���k���x�w���i�0>�"��Ԡo%E���E��u�b���4?d��g�)u�=�D/��ꦺ�OGm���j�s�G�+��T�X�EH�H�s�N3��4km�7�t �x�����VO�{;���3q]b��EQƫ2~F����E9�3�;��)���?7jU�4��x��D��%�zEl:��jc}�8*��gJ,��ٿ�]���{Yt~m*��6�7���^X��|��G����Xز���yr�t��_-�Z����j�%�R�}sh�=ߵϺ�g�$�C���.��I���$����v��J&�E)�R����fw)��y��W����%T����Xa��|�"U���������R�ďG�
�7rk���J8Zrw9/�Y����]!��s�~�w�.�-��ާ"����5p9Ո���py{�q�|��?�5���(�p�q��hOw�){{saB8�5T7�P/��P����t)f�q��wD��m�|3kw�*�̍�7J�w̭;��2�ʤ��$1;�s���ns7��u�*�t�R��;oaR��I!������� =�<�p]��/�3�I�W����������r�!������q�,$�d(���p&��^|#mDuy�����[^n��G����5\�xY�0n ߅���v��bq���K�u�}�n���1R��Q�]�k6q�eO{�H�Xb�Μ���Ĺt���7��j�q���$�k���g��׏$���.�lPGa�(�dS�j��q�7"��*4��`�k�4A�v*��-P�&�F�����䥳/�
��c�k�l�{��\B�.'��ǸN�lS�5��&[Hf�\c��5��j�����ť<�q���40Mхt���>��*�+�M�-s�"�y(�!s��f�Ѱ��(*�����Z��y�f���Ri��?_��4g"��wl0b/������7s�k�Cy�Y:�Y�������Ȓ0w��j���s���&&�K=S縗<98D�=���l��C�%����w�C�ޮ�ɲ^+�WP�5������'jA���P�?s���<Mܨ��0���U$�l$AW{L)��;��]�X����(��V��/�J�����,���%�s}D��9lN�� ��;KNU�m�����.�f`�l�2v�n�{�U�e�و3EB��Y�,!��+(y��o_�NUKQ�<4��L�u�?����f����xo]�o�����{�kHK�*D��^�������
j��\�yu���Pv��i b7�4C���#H��*��%[Cir������-TE��%Q{O��p��^A����(#g��5���[��"��XǢ�?9'K�A��Q湵����e	�����:|��R3r.��3�e��Y�ySc%:kkq��WK��~�7�h��&���D����q6~*P���8��{�[X��k�~G�q,��
tP��
*%(� �n YL�3ɜ=h�ZϏ�?Ӓ�;ƻ ��N7̹�����튼�yUd�WI�mδ����%~�6��'9k����,��94:�̈́y���]�"�-i�+�"��?�9�G��1ϯ�P޴�}�Tu[8�7�XK�,�����|h/Y���(ģ��|��}��+UgW�Rx�m��$�h{j7������t�y!u��7�`^00�q�#>o���Y��<9h��抡��&�]�W�q�U9����\Cy�>�Ǔ��r�	3��i    e��;(�e�!�fn�en���0��F�4�vχ��"ND��sX8��h�"�M:��^Ciԡ���o�\�53�N�H�&0(�]flʓ�~_�ԏ?��9���7�:7�Qr�p�;���QE��c<�jE���جX��~F12+�'��A567y�LN!�w�����joh��ב	�Җ��k�I����Q� w�~�ڣY��mq"�fI+���`��|�3KS��s��p]���d[��C�]�K1<[(J��H�a�M��.�B��	ė���1��NYH��'�@Ej��6��a�m�>ెj�k���(4�sM�S׃�fO2�LeR�Ȝ3��-J�<{'����2捁\�"�n�Q� O�3��K���`�"5���	>�"1jS�(��F��ƹ֠���gE��Q�l����]#�䕡7�t�:�s��uL��a��XR�U��2��rV��-���	
���ˁ�Z��MN�LO���el�2���>���N���PBd	���IK�$�ŘO9o���[zd�l�a���r�з雰��C���]i��.�N�_�#�C2��:�+�bQ{خu�i�O�n�8bh4$��$�3�Ð6�o�*�C����|?��⹺͊E�4�1r��y�Ը�&Qѽ�1�)W�>,i�"L�0B�<**��\��m�tިn��uYN-�yF��87:x1^�!7@�K�����c2}l��I>|��V+��ۊ��}*���5��Q�98���yw|�|k�Y�ܪѻ �8I./�3��e�Ȍ���e$�|`�ʙ`���X�N;�����l ��[��rl���jk��&t�/ 9�y��w�^�ý`Q3m+�&2��39���ӯ�H9ERҭ�U-R+::K)IWZ6��t��;�a ��w�1uH׀de}ьjo�p�;)AcsSq��wS2�@�\k�ʎzh����w���7�E2u�f���4떭dA��±>�w���s�sB�Z߉�?�W�Ko�s�]��r�Y|M��cÝm^�2�!��}U3�:���4*Vn�g�b���إ��e��7I�3'"�ڙG���	���],S��T+���g��%C�*��1��o���F�da_��KNm�~wr����ҙ��>4���?�������^܅�UEﵰ�d��q.Xsj���̮�lv�����}�&~I��!���h6�+J�<s��{�G���1���4�����djl��9�J=梑e�l�}������M�W��hI�f%�q�����bo��ĳ��]Ք7���'<58=��JW'�tsA}h��C۳�
?�m4��GJ�8�T�n��#!B��&I��:}�0o����2�Fݙũh�,;�Q��g�㮹�vT�2Q<��uo��c�X���Q{4{qa��G����c�A� D�"C����3�l��ds��C�ow�T�'n�������
�<:���j6N[��:�Eu��=��*&}Zyz&R�]��R�V}�Tm���`�[�����|���Ƴ��6hH��������k�@:���:>GW���|���X��b/�Jn\;��K��Bd`��R��Xx�/C9����2���`x/�T0n��T�'8�9s�8��I)|o��!�x�,Տ�����hZ�j�;���G�6����;�0ja�)o�K�H��.��k�+.υR��/;ДYΰԚ�(����!�/��Bꯌ�����xz샞RՓ��Yڦ����!|�/�����*��k���p]��)1����F@�3�B`b؎�֓`T]��ƺMi�팚���Y�FZ2r����5c��C�Zsp#e>F�S��� ��$"���@�:���K�D��u9��N�3b	0b�Z�0}�i�*rf��Ggs���� yfz�#G%^bZ��cK2�ɯ���l!b��+�� zKz�Y@_`�H1,t%0y��y�����`��	3*�2�U��ِ;�e.;K����C>+C����R�!I��������px�Dd�ʹF�i6<{bTn���<"��j~X�x����C��DQHj�\+�n��,A
j_n����=i�X��9�7�oͱ���r2m�76
SI�Z�ʪV�x�6-Wj>s�.X�d٣�;k�"�LX���+�]{�Uz>�]�U��9�����4��x����S@g��Y�=gr�/ښ7�+ʭw}-�z����kl�@܎ܥ���8WZ�-��Ӵ�����hz� �O�ݬKIXJ��d�X��2���a�v["K�E��q2,Z�@j�̾��y����1�u�=CS����Y��}� +�X��J�ԊHm��iNݧg�|1�%19ˠ�s�$&��5�� �B�u�J?�7�>fl,������N�L�Sꋉ�OZ��&b�&�����@y2��NLӡ
��&o7�kzBԸQ>�8�n�ʭ$e��y�G�	f��,��ݖ�1�*�3���L�fYb��ள�x���H_�v��7��C^C$�b�	�p���j�:��r=��Ra�b�O}�%�Sq��p:��@
��k�/͡=Vg�K�sGDo=!<�q�~�V�%��ȁ4�6q�ٽS	�d��V��영���y�>�ůE+~!���j��y�Ǔ����a������(0�3��pT$��`Q4z���Ct 8�� =KU�1�;���8��v���s������*�BO��`|��gmcI��g�q��T{n�]�.�띍�P��i�䪟yR�x. ųiR�I����P,0.�2~��g�� ��ݞ1=z�2T=��Ξ�� �A����'r�:�a�h��1��#Zg�;$�1}�X#���/`K���w�v�������G��p�Ăó��u2s��?%�t�ho��@�s`-@�B��XW�(q�>®�����(�lh��$@C[ъ��/k,�.�n�ШԵI��7\��*�f�5��3D�6�o����RE
�k+��-$����Zy۫3�E˽?/��Φ�B��>��cY�n��
 �A/�Q��s9�M-�*�����Uqa��?�ۉ�T��
qӞ�dPT��\�r\ �ţ����v�1�x{�m�� ��`�����Е�t1R�0e���5�������Lɒhmd
a��Y��S��͊^w�McFl ����Cl�9R���f���jf}�͡�њ����˶6��M��]`�%p�D'׽���T=Ƃk�*u�M����24�b�&"a��5�<Ρ�����k'� E����.���s���M���ƨ_��`dQ�2����Y�3>h��0�X�<���s���0��������8�b���a3�=�Q�z?*�˞�R���������N����:�APh�4���S6�ټ�C���Y5�9	9����j"##��Q����/��95~r��q�xz4�q���g��0�������9�P"`u9�a��Y�`�H�7�ň�6�g�P<1%�����A�*�5�mZ��H�֌���F:���TN�L��Ro�����0��+vhM �E #�������9!Ƌ冭���'ނ3�:
�19��2��=�a��z�9�^&?i��R��M��@�������rX���Q��Vb�2M_h��"�'�L���nJ�54s,�4��c�u/A�%�.�ʞē��"�q���,{5��BK�������ɹwv�U`�����I��*���_��U��Ѳ���=�@��c�����V�j�����a��AS:�b	|�SL�&8��*{���py��W���{�p���7��w�y'ن9�!ީ�cd��g�{��Z+��k�܀a.�#���x)�H��d��F�4����bO�>6]��=c�R_�	�ͼ��X� 1�\֯�ڸ����"v�.�tl�S)*on.?aM��Ɖ�������l��L~����ZfrH��}:����-n�3/F���wJ'i��|cWH���|����YsGy��Qݔ�oM�9'���gc��0bAϒ�R�7��x�3S�v32\�N��%�6�YS4j��ĉ�/-A�ΚS����Z���7QBD�]i�@=I2ݜ�bعi�6*ΰZ�TH    �'�o�L�bd8+�Ƣ
��ƚ�I3)�	��}�N�����{g�����j_���)��v�.U��Y�4��mqզלJfc�ӎ�z%Ʒ�G����K	��ˊ�a9d%�xz����$��,zg�{q���#7 ��;0龹�1QV- ���ṅM�;ڿ���<q�CNW�~��H��N��R���)�Xh+��IwI
F��e�P�ѝ
�,�с�
�5�����-'�0�n��A���MF��9����B3���{�L�_�/�GZ�
�)XF�g�����S�H��2�8U?ٓ����s��M6��"�	�����lԊ�3�"yn	x�u��aǖ��d��7�ܺ���-4��?h�s��?��%����F߼�y��7�Ʉ�n|�s˕Jm�%y^B!��[��Y���_L���0NhdU����#
S��� j(��9Uj�nRD���_��95��+W��G�Lv`����k�w��Trrac"��
��Dڼ*����sWE�[QA��Y/.�/^e�ml�r~��z�3W2=`�
(�.v~H}_��o�bj�*<���\�Ο�J�c��$���*c�V��=̯�6ɱ��XG�qL/4cM���b2>������K���	��=g���M�����g�Y)=[>*� Ñ����_^ױU��xZr���=�oD2���*��t<u�c�h�w�q����"�
����@���Ճ���*{䅷�F!�������F���'����s�ߪAGz��^�]Rݺ^��\��o��|�^9�Γ��ZLW�3�5��yz�y%�!6��Wb��n����	o��;�������΋H�ȸE���mJ��k#z��O�����SZ�HY0�UNL���N�C�	�NHk�o��B�Rq����I��	#���\��1�TB��G�w��|ku>�{�צ@z�Q�p�Dz��
"�R�;�̋�8��P?������A�����4<�fa�����P�T��H�}��2�c;��:(6�&����i����!`����_�������KS�u{=͉�]��؏'��4��j�|A0$����=�ӗ�t�3͖4��>��t�#�y��S�ǚ��h�3���5}���j�+=d�����vKe9ВYT���6�׌�<�`s q@�wʭ��ᯑѯ�\=1�A���%!5�Z�XyL�տ�ͅ�X���;�¹z,Ƶ^��G��D[������ʲ�m|.�_BmJj��7H$6w/�!�g�rh�h�7��I��H�ua�,�H�E�u͒.��X*�Pv�q�4c9[�[���T���{��q&.���춌r<xn�%�o��>�̭�[c�<��U�u��G_\�U����2�������y����תy����-ϖڍ�M��2;����L��7�DN����7���7��˅��nۉ�Jz~�`�eX�(i��Mn��������e�]�g�2���ܯ"R�/c6�#t�5�Ґ��Q/�ε�'�F��o���2"�~|̀�����׸�x�Fo�E��0'��o����i>`�Ă�p��AtR�� S����W�';91���c68a���������>�K�߉��U�8 )�� �8�|teC	��ύ���u��]�-� ���yK�4���0�v�V7{�A�{ctIlML����V%���VE�H��`�v���H�}�#dC���yv�͋2��x�	ȸJ��x!Vp�o�a�(��3k\ܮѥ������s8s�S�gr`�L����E�Ө�\����`<W���A���`�J�(=qs���R!���c}�-c!��(�����|���!'P`�@x��0��� W�r%���Ԓ����T�����`p�1�g^�"��OG3s� ��Z:���G��軍�4𲳉��~�K'�.UY+~�a��c{��x���׀��ځgn�A��R���u�B8���[t��PKg�eϺ39b�sS?�K��1_��^�	�Z�4j�̛� �ҰS�(�^&��]�)�cA5�;n��0��n\�����T�{��Ibٌ#�b�njC>���lF��hv8d�nv%��.FdF�6�~�)��5�)�Ǜ��hb�|���+<���Sρ��Jy�1O%1I�D�<�6Q�S�2n��|�!G�֯�jyj����)ǁ��\{�m�ċ�88)�'I�-ߗO��3�c`R�Yz�ӆ���\*2Å�������aj*!~wx�cu��o�ClgF+/0�df@�0_�U
��N,�q4���sb�@MV��C݅���}}|��N���e�#��-j��$2���C�`N������E����Z�1g̹��c��J�v�z���'�Y©��b�_lB��w�d3������x��BMa(>�V��c\�ـ�b2�{uK���ʷK�-Et!_C*�s@��յ;8>}Јy���5]2�,�>�?X�E"�_�ϋq�Л�OO�Y=(�G&�!�z���yW�(^ou0�Q�p4��#,���Q�ݟ�n����/gZ���D��#�틙頾�	Vb��F��T�k�¨���8*m�sa���*ׅ^�b��su<W�SS{�zc2��j��f�Ќ<X4��S���Ӛ����RC�s*F}-M�1��!��;����{=�0?O~��?2M6�0]����O
�c����s{7pv7�ӘJ�>{ׁ.���;Y��(�צ^���.�s��Y��;P����>���wj��t�{{?�`e���#�nAHş!��]#��d,���R�G$�؜L���n�E߹ޟ^�!�E�S-����Ѝ�br���pIt߷�߼���1�W�.�+s1I��'�ٌ4I!���r�|D��a�Hok?��J䤹��7.ݰ3~���L�p���c� �BE�XY:���RV�w"����B�M^�j�������{�wuu��C,�Q��χ�^��S��=ni�z<�0&Ps�`-��c��u/Q��j�2�s��&�ťev�#�n��Υ���Ώ��w[|��ϔ���J#�`�<v//�n|#.W���Q01�f�:�T�1�g�Q�˧�Rr�1T��v�EAP�S��g���S��L9��z�j�mK���>��bd	�6ֿ���];��+�z�:��]%��,�|ԅi�f����'Zr(_�d�C�]��U����˘�NTi��p$s�^mߩ;�n�F���+��t��㋖��7/��׎��+�|�_}�������t�9w�;���lh]Ƅኟ>�Q1�0�wi�s�r�5s/�ҏ�j:��oX=�`�Uu�8C�M�(����<T�D����3�HlØ�NLL
��P2�:Wwur'���JG+�4�I&:-��:��fľ\�����!��U:'ߞ��>��J��� 6�/��ilf�̇tj���G�X�j5�-bD,!;�?vD[\��M�c�nT�����p6�q�K{����3%O�����>�4�y��)įA�\v��j[�7�V�s�;��tY�x��ϝ�r1�ʊ�~R:�s�nW�H*d�+0�HF`A�n}ctBN�A�M1;��Ɍ�O�	C��t�+V39��]bD�J����=\�j��y�m���A�<�6&�{��V}>�p�D`�r��$�|;��=�x�W/l�|ݟO-�Y��	�ї���N>G8�a��z���R�&�?I����']�C`,�ld����gk���W]/{U/�fxՐ���n�O�[st���35�!�ǂ}��>��t��T[�WWm�>f�﬑rm2G3���+F2����`$[vv1�j����\uտE� $�C<�+#��ЈC��Ѱ��(vQ3�_J>'̷0���R*�&�n���,�J�E�a����ŎA���H��0��g\��f)m���v4Q
�� ���3|���p�Z�!#O<�6:B��d2����r'�G��Ur��E6�*c�#稍k���삉�l��W=��"��@f�/Z9I%�~�\q�\M�"IK�),�a�,�J��������HrrH��[�`�Ӻ�x�;ڶ1��m�L �y�,
#�=hnU��    �5e���jz�߾���*��>���l�L�k@Z�K��\:�uQ��C��%z���ӰI����Eq64��8㥳�NO�=���8�|�|r�<vH8Ԝ$��at8��PS|�Z������T�z�T�L��������
l#�"���~�dI\w������ʇzS7�O���^�-1�y��Ж0� �*>.�pw#(�|`@������X[��W>��C-@b���*:�|#Ϡ���ǉ�"2W>�e�HaPS��`��^��tF���KO�D]D��R?ʍ=O�ξ�p����g��(��)L�(tH~tڞ���m��q�E�'�#�R�^ͫR"������pr����rO(ȡ���x��lß�{���J.�C�8��3[���P>�]]:p+�0Uznh[�(\��W��O+�el޸(U�j�i��@�̐��f��/a�(��"�RL�U·��C�	������c.~��2f�6��p)< /�����Q�=k��Ko��B�"�8�VXZ�W-Q\��C<�k��n��$O�q��^p�TM��X�Df�l�O�2~ �9F����F-12���I������YHw��R��OW�嬟|Z�Vl;{x�����k9���T�@�r;�<_`Oh���Ԋ��G����U�ɳJ�3a��� ��&��мmrc0�_'Ӻ��r�צSZD\Oy�J�xTN����E��4���.s�٦�|_R�xuX����̐��%{�=9�	�N���Hh�	��P(�'���DGvؓ{�m-��1�Y�����������5���ޱ
�IY�F����u<腎�3W�C-�c�rBt���\�6��T����By�FG���Q�G�=^繫�����&��/F)�̋��O*\"]� �X�<5{7I�]x>�/2�p�X�s�uf�|�_�Ry���(������a߸|8&K?#�4�y�L���+'Y��9��G�Ĭ�&���q��exƘ�K\�K�i�;ey-��nBM���?��(`BN�p�yMsh�չ3<�*2I��3cT�_ ���hbZoO�Ӡ��5K�OL0<���ǆ�9
��'�=� 6*u/� j���M8�*�[{RHl;(ە�=z�����&�����#�f�$�����
�2{�a���p�%׬+i�n^@�7�#$D?����1\�ރd�Y�����i�a�jz�^�R��JK��l���S�:%bd�b����F!� ��'w�3T��ϱ%7�K�����ڞ��	<��z}����b�J�5��u|T��)y�Q��\\��Z�C���j�§{�s��=L0�Յ3�<��?=8�RK�4����<��S�'�s�ݫ,����RE�P����:͎:�k]<#P'oI��2u�l��r���#�;��M0���TAN �`g���^��
���=�啑��-�����I��g;s�:%S.c2'W��D��F4ޙ��:�U���݁���423)��(�Z4n��L��Q� ���ӝl�EҀ�5�D�.)��jE^�΍(�Ȓ�(��V!�Oa#���1[���"��A��z���S�(�lr{���'9�F��KI���Ie?�Tn�jjҙ���L"�U�3ƛ�<�_	�u>�j��_�]��&����<�J{r�|v�GW�"���;�^��[R��b?�`*|R�T���b�=��Jژ���ot0�����'91��sf.B'���,�cAY�"G�z���T�g|_Znߕ���U�>L/\��R�"�̸}{Դ��L�K�yم��[�c���I�9�QeP>d�0�/9{�3O �Ʊ;N��l�CY���(�T�$p�Սs!kg���`)��	�R�t���I�X���5js|,?U$�����eR��&Ex��b{HpwDԧ�~/�����Lht���!t������|-#@ޕ��!��;5�v�֌��I[����y���x{��]+�O���Dp������v�4s�q�u0gF_[\#ۓ*�$q8ߔ��|��*�g����K��-���n^�ث`������V�	�y$	��#c�^��C� =��o�xȉYz�&�guꞢ@B|
���Z,�vu��r�X�ur����c-�@Y��s��_38�ht�d'Y�h�̐R(��¥��'�����p-K ��PI�KM�i�����I���]��H� �e�۳�&R�r9.�z͋��j5��x��NK�����ɲJ��b�@-)�H1@����%�`m�{�ݕ����ɉl ���&1DYDBɥ5A$6N�3vں�_#���9f<n�ff�`ĝ�aR��/f����R;��1�Ġ����H�/����g6����(REQ���/����@�1
�D"[YQ+�������_�@��0�����	�I����s��Ÿ�Qc�o6ffE���yZr��0�&*�b`p��§������H���W�י�轸Q<�!o�bq�[�E��Ɂ�����;px�ψ �u���TK�/D]s�X��Dq����W'�99s;�2Yf6�#5�u5fl�Sz�2�����r�2v@$s�'�C㷂�P��(�.��l�13�q,y6f�ɛW
�ȭI�ҁk���R�Y~m�v,�z<g��� �h�x��F��E$c$��:-�0��p'���` �ο�[��v��liK*�޻������t�U�ȏD�.�;������%�"�^��Gx��Sr�^~�7��G��wYz(9�b�*3h��y�{�x�Z_���rz3�:����()&������ǭd��dD֚�%����o�E�K�-����I'�rB�D*!U럆�̶��Osf��jNN:�?�l���J��ɗ�C� ;<�E�b����(�ǻ��K{E�R��D��Bg��g�J*�����uᤗ�~��e��Bit��O~�m�yZ��f�EF\�a\	�?,�����-��ѦiK}��A��r$!��':���-�TB-t�֓O�ŷ=&3�[ ����}�/�-��~N}��b6�J��f�=�_;�25/"�W �����-��-��/�G�3�W�b�ޘ8ș�p,���L�も����F��m
�6qHՂ=I�l�=7֩�����������ҡ�g�(��p��a�Y�9gc�/Y�"B���pȰ���gc[���-�������aa	�[��哬�3��7xd
��М�Q<;;Գ�P����V��q�oL�"�J[�cL(�����8���,.wh�{���H���n��Oj���	�K��u�Tס���SkC%л��i���3���T�i��>Zl�I@�K�u	%��9��3m%RD�i�2x>�|�J!���rD�v�/��PY^`-�P�@��W�U�=�X�C��&�Ә[���uh�՜��w�#ÁyO���M����Av���,�:`�
�����{�J�,��u���q���!?�Ǽ%19Hs^��
�q��x�l�k�"�	8�8L�n���5P��P靚��ĳ�8=K2�kX��{@�)��d�x�#r\��X�%�ݦl�Y�P�`�jݹe[9Kz�Η3���鰜�J�!kһHu,y{�#V�q���-�Hک�p�S�aIɞ�tЅ�E-"�*!|���2�a��8���+� do��l	��l6_��{�ɪ.�u�+� k��\�o��l8�[�qQ]��ǙS���[�W�m!%��FͨI�v#�>�e�Ybr�Ң��cor��e�RV�`���S��*5�#;��g+!�X����fY\}���$v�#x� :�{�`�^;+ei��7�ɗ����46�O-w* +���#+�j����[(����v��n^�&�9$���8� ��8%1���]�&�^M�)��)�^)홀���d��v�B���H ..�{�<��i>ԇ��� �0I�7H��G/A�ƀ�(�������!���xWcP�ӈ޸�����_"Q���,����h|��6$L)waK�M��\�]ME<Nd_]L��|L��`{��a��w8.�!����[�.vA?J�+_a1^b���D���    ���(��i��v��<�<�y�T^�n:f����捲;����k�3���L�-�� �'�B�w-X�����n�В�}��p^���2����� c6����e��۩��;��j"�cd8�+!F��ح/#/��7T75�C�T��8kp���`*2j]��>~m�xL�v}�e{ �H�H�w4fӼz�����j��l�H����߷O��A|/���H�q���C@¾�B#����0eY�C��"�9��G?te�
*4Tp�� �����g�����c#/M6^t|k�i�ɪ[�NB6,.5�dqB��*�H�ʙ�81ӑd�\��K�������ճi%�LX��K��_Lu�5�q��M�fwD��s2J[3��LP��`u5��Lz"b8��v�d������tY����~�_7�0��}y	v��8r��{ I�+�������[����c!����9������.1��/?�uFB���##�۰�������lP�vH.�c�n;��8��z�F/:�[Ѓh�H�`H��A�����
~�ʅGn�Z�=<��(�EP��E(`�f ����/�d�}��4X�E
IO+�H�P#e
�b"�u�c?\DQ8����c�
iPm#��L��r~��QU�ߠ�?�Vd���?�l����e�5Wʞ��q�����{�����m�b^<��?�jG
�'�ͤ������AM��
F�����Q$C�8x�(��aZ���e��jQ���pb�}�I�]����^^��-۟H�#Qr��

����CB.p�}94��7ѹ���	�u]w��`h�"������@=�ו�Q���O}�v�e9����{�q��;��]gD��
�2t8�b�G�u��Z�J2�T}ڦC��=�Z/M�F�����
"��S�?+��h63E�� �3$�z;b���apy��9 ������H�j�©�&�Y�]��"or5�ڛo`� "�J�����;@=@���͟E7N�+kpj�K�.��í��Ҩc�f�xh��~�k\�����B蔽����m��]���c6���9��p�
Zm~�b_�]{g��
C�5A$dF6��ʩ��z��>�����9�E�)Z�+����ߏ��̽��b�����T;=2KK_x��>����s�.N�	�qiN�o�����
��;T
��e��/�\f�P�:l�@x���lb�0��3tP�6nݼӠ�h���{�4Q������,e�k�~���фh*=�"�u��U��O��j�"�rt�O�����|r��O���d��qq#�	�4�6$� ʑC��vP��on��XO�gO�k�O���WNFy7-<�d��]o5[l3M���Z%0�
&{BP��x����m��0M @���I8y:n �-�ZI��p���~14{��I�0f�=������&��h�q�a��uRÑ6��VA=4H;<�V���!�R�F����dٝ��$�	�h���fn�N�]�{a�OH-jθ�Q�Y��S?-U�=�=vk��(�>��V}�,�sľ�� �cQ�*�0@��fs�5D0��v8��>Ym��'˭*��v�Z��?�nF��|,��â-	7�~��xf�f��$��ȥ��9�^?)�[���T���?�/�F>I�Pb�ظ'zB��6|��]��|�[�"�	d���[�@�`��=�4���&v/HQh����$R�o{��Z��n0�(2}<}3H��3C3�e��x���޵g�`�Rn=W;�tȐ�P���n�N~������D	a��h�
�~Ăv��0j.��b�l�TE\���N���<j�m�1�]��}b�J1[@� '��Xᵹ��<��%lv�%�\S��¬3ˉy}��]�ިS�b�<�r��z�R�\9p���v��������а��Ȳ��x�	�$�1�X�F�#)4�uM[~�m���T�@B�[��ژ+����D1�$O8r1[B�����x�<��N燃Gi�O����y�Qh�`ƥmT�����q��X�{C��{k�)+Ԉ�7�S?��̮ ��C|)�� 76<Ab_�9?�Q��x?"��oqY"�ժpð*�j�0�R2����b�E}�B,��C-�����n�'����
�ɬ��UN�IV�������~���t��j+��S��\J,�7-�9�$.����'�t��%�_	�X�7�T���sj��Fw�K���0��ٮ�5�mXA���{Y��UE���gx�����Х�!�o��˵�]��z[~	��fN6w�5օ0	ToSDg����u��^9�,�Y_�Ƞhi�[�kj���{��Uz�эT�E���8�����Ho��ݸoIg>�K�ӕ3o, ݀�����2QòBbw���y��rm_�� 쳕a�����c��8cե��s;+�0@�x��f����]�4&=g�4�8��W�bG��Q=����^� ������9�AX:v�4���앖�cJlщ�>h�&#,�˄�/y��U��f��Ƞ(j4��㡂�a[1l��o����OtsBbt��{J�M~�łx�+���ڛV�񄝙l��y�S�g��;�!$V���j�*
}D�*�XI��-Н�,�nF��ݽ��2�=�9�������g�)� ��@� I�]���x�k*ִs���~�LXh:K�1O<�^5��|!�	8��'�"��.�O�#͔;�1�#鸹�O�JY�[�6��P=��CQദd�^�r�)Ӌ7:�=K�=E�s9�ͽU��0�?�����dj�eꑲM�hC)�����P`�V������K�F2�HR�}�[8Ac��̑9���A$�j@�®ذk�ƛ���Z���*�}��]{�0�ݜOrn�_�z
�gW*�����(Qg0�^�3�<vK0�/��J�7��wCM���k�FAŤ��1�0����Ψ�l���C�b�J�1s1����Rs�m�8�T��T�øX������γ;�t�!v[����Hz�c0Oh���ݧ�&e�.��p$8կ6F�c�Ѕ��~����ӟ����ޫ%�\r��4p�J>Qڤ�mY�#E�^��?5�0ދ>K��#�j��n�#"�Ti=���Vl���{����I��<��	�~�%l�;��\�O:��z|l�ga�'D��cK��원�S0{���_G�7�(}ҎK�i�C��
+ 77TV�s!dC<���!�8N~��m�,�F����\�΃���l������fWH�Lk�*E-�I",����ĶF�I�iA���
e��O�m{��&xIX���o|�Z�6�;�<L"�]T��� ���DIiK5���r��Z4!s(��v�ts��i���r5w`ud=#��>w�aï�9�4Z1�FL�d�-�psw�(����Ѕulm�C��v
Y�wA�}�'%�@�~�����䒑/.7��X=�V7�	5O�ދp�S�@��"�ZOqI��z��F��[{8�~��?J��Z�9��;�v�v�ԈO��]D�A\f�|o���΅I��C�CCkc��Q�����o�Q�����([۪�L����Yv)X�v�+�s��8X���cs�E-
��ك�@澅c��=m���/�����ÑĒ3�*�y�=N��������J��)pз�������:��8�Bqdgs��(��{�S��\���?�Υ���\��"�p�b �B�֟˾2��ӱ¤��r	����W���	��!w�R�!��Z��-���]&� ��t�]��$h�i8�ݣ��3�	W>b(���Kx���v�R���d��<+�<[jy�T�1�`c0�y�i(�nh�(8�6��L��OE������a�y_���gѼ�8��ƺ�m�P�/8#��y��䋫i=�i�9��:�Z8�ݩh�/
�yrL�E����j�=$�/"��i���y�E�զw�&<�����J��	GԊ��ԫR�d���k>ϝ�X��8��o�Oj�e&�v��=;H��k�k��`R��_J&�4tʤp�S��sܚ	�� p�o��g�x    �
�wܴ���PjJ��1HU��C�� ��u�MKwx씀�Zڴ�0J�}�3�({jΥ��鑔J���y5��M>�J��d9�ذ-�0آw��� �`�̈c߳)ĺ@�NG<� �DoyrYb���D�D@����9�a@�R���rJʦ3��-	A��3,#��Ua	aHv�n CFP���/�Y��M`��|7Nw��X��	���V@���̑;�S�洬�Ĥ�bY7A՛�b��v��;�j3�ӛ8��CZ����z�kN�:��Κĩ�B�9�������F���kS��?�{pz��]�L<��?oGv*^߃i�m�K܋9T3gHK\����U�^?ýDv�t�	�%��"�v$zR}���PC���?H	T�;�ى�.s(N��@ڧ`l�܈4���ԇ։ �u� �
�_i�e}��ն��a��@������g4 �4~��kvB~=_\��o�Q� E�e;H�8>p7�)Ē��W��2�O����'��)d���&�
i���$c	a�W�6�;�p��|2f�H��B�`5�����G*6X�/�a�h+�RT�`�<@R8_B�`�}j�o��q�2�����cҜ�Q��Z�wm7�k4��"N�@*��CK<vOW�Ň��C:՜�
[]i��?��z�Z���'�	��׭���&���ߥ�w�a-W�i�'�t�H��%ƚ���#���"����;N�B�h��(�ʋ��Q�8h���>����(a�#�N,Ŭdݭ��׎�Jlh�j�I�bǤp�>���b1����ߎ{���,3ve�~Y�d05*�p$���Ap�z�?��Ha�L�!�ezYf#�.v��Y;�����S"F^��b6wK���4#�
UZs�7V��H�Q�W�˙�����jĬ����Fl�
��"���0O1��=Z	�����3Mq�G��F����s��ǨdG���o�On1��/>ct�d��[5�����>��˷(�~�?D�O@��]=8.Bd��a|ĭ����L)}�[��i��Sj��@��OV`c�P�1㷥��y�b�
ٵ�y*�%	O�b~��?t�ܵ����	�*n��u��.ͪ��&�ӿ"�z�d���a�Q(�l�����4�Egg����б�9�{���g��h���>�3�񨁜�����x�3���\1��T�`G�rr� -�i̘���r��g#�%%M�S4[�n�zŒS$�3!\@L�ջR��|���	�[��ͺ%�~*8���o�x����Z��]�2��Q�Ѿ��Ã`�!K�\Fb���j�S�CY���t8T̤LνH+��e���7��d�\����]��{�r�������bD�$��J��Z�Ǵ�=���"L=�WB��w�qs����	9+�(�_t�
�������,V5w�䳾��k�.�V�|�,�"�K��'6���l*}�`-g��q��%0���J��0��*Hn,�8Ν�+�zE'!�dļ}kh�֝�Y�8�=�T���y�%�PB����FJ���� ���h De=�͌x9V�7P�dC��Z�(_Y�)��9��s��0������>�ռ5D�=���k7/|��%�p�!2�E�����J��n�C��ً6���q����V���sgL���$[��6��? �
��-694���$Fmg_��Γ�l�)5�IM&K#mY��<��g��%m�����9�l/�E8]7$q�P���[U�B����v;]���f�Հڲ�l��J���pI2�N^�4��"h9\:s��E	�E��N~m����OTz��ac���� ��h77p�����L��C�Cꑨ�`o'�Pw�k��n#����T?��L��rӠ��d�~��.-�,���͆�e�(^�2L��ė�z�h�̢��,���v&JUf�Z'�xj�r�T�F��䷗M�J�+QP����ʝ!Z�!&Sr��D]�|&4+�x�L\���`ʉ�m��8���A}�37��>��=�����������-u�47!��`��d��63*0�;�D�Ե�$Fc�����i.�d�q�b�8�-<��Zx��爺�y�XD(���HLB꽟�Vh���{�4�ȹ��6�hF�h��=�X퍠��Fs.��ꟶ����'���N�⎘<�(�%A">�	�T��o���ȳ��@Ni��Ϭ(�j?�yi�C���N[��3�E�	������E	�i�d	=<���l��w��|}�Lַ]ɾ�?� IJ=՚ܾ\1�--�ڥxw	1��	]~�}��Jӓ��&X(�8��2���{���m:�lI'�'oƻ������ֺ��( ��ŭ�Mva,0��su�'?���V��*|��1	S��(C;�������rm6���#U�V*\��i�%�o;�6٪vY$X�ي
A������@�§Fr�;>nM�!��%���[.� Wj:HJ�ά3�D��o�`��=a,3�_.0r�~�5qA��ڙ�6zBxN�埤C�e�q%�;֥�pcheN�uB��H�����^b�����ηR��ل�8NlN��e	}���KFs��5?��+�ŀ&>�*l��|l"�@d��0a	�A��jUx���;AϓO�(C���g�[�vX�jH+B�f1"��kY#N3��H:��Z��W�����5j&�a�:������J��_��ܡ�����=\��򳜜j�K�Qئɂf�Xʈ2w�����3��JN���Z�0�1k�o]�1�5��׶U�є*AZ��6չ�]}<mΒ��w!��i^�g���Zf���� b
}���ڶ'N|�h5S1��иLx�DRpK�FԳy
��t�7=�n�\�t���?F������q��d�"j���
jxf6w��Q�����H}�i�;m�a|]]����H�ϨO�q�����iH�b���P��!]JC���ĺ�����]��Cs���#�۲�L.=p3+�v���膾�8q|�2U� �vF9��P�� �I"�/+,|ZHY'�5=�9Cb�s�� {�R�:�a1ƈa�B���� ]eGm��P�������R9�
�yC�pj3��m��l����4�I4�b=nB���%R�$�g��-e#�1�2��ΒYE3o��@��n7������K�-ܙ�{<�*�oi��^�z���_1m+��:�B���e����%�d,�_A��l��8��9�~�$JQ9���2��C�\��D(���XE/nTk�����hr?�x=�5a^A�Za�T��W恰��QZ!�NR�j��5$���=m̘-9���i3>��\�Թ�?����zh��5��AH�6�����cUF���]c^�?��w��D�{���Y|`�#(b�HF���YX�%zɒ)�V�pv�kH��/ǉ�N�N-S�sM�a:�\ئH.!��h�]��|���Ҕ�<�d�_<��i'e���G��Ng�ή~��J���t���-ZI��7D��� �*��t�䳴���3-YΈQL��w�Y��z��UJ����==W��*(d�c��P\���E(�ez^�A�i)I�&�Jk$2*���I�����ϭ�;�����=�C&9�jt�C�9�ݸ.T<��>L~9DƳ��.�zZ.'���+�l���*sk�_*}o�°���CI&�a���\��G&��<�� �!��Փߛ�}�/OP&�V���n��ǒ]o1�S��=.Aݐ@�F�J�*�CC������뫿�_����=]l�Ǌ	L�l͘f�QKe�ciQ� ;�=��2;.W66&#�-����2�Zs�H��_/`��p�!"-d�{iS��h��
�+��v򢳼�հ���n��4њ��K�3��l.���G@�-�RJPD�b	1/1�;U���c��p��RDl�V��'�(��ғ04BY�L����V7f��~�;�x��Y|ֹ.�0~K������S{����',^�ӗI�Ro��,V�>E$�^�c./á�F�/��'zv4�����9r�=�]a|��M/8���e�#p�c���47/�(��W%�n���t�y�䋑3&�F�믱�֢�s�5��    Cx㮯�X��?���,o �	�1a!dZ��iȯ��!y�e���xd�*�pe�$c�Cy�lo�--¡a)�����c�m��s��ђI���2M[-35�U�JS͏χm��ذ���\v%mK��,����*t������o�		�&�(;��k;θ� ���s;�MC�}(!����J��#��r�T�Ng9�-��E��Ǻ-8oâ<޸Qv�	rc �|�Ud�������9�!m�s	�}�%�mɑ���R_�
߽��}";��w��"���HM{r�sĺ����o��%�˔�����N#���X�%)���(潬I�Q��Ȫ\�A��h�|���_�����S=��7�B0���U��)��m]��/m��}�8�wɻ�穞�����Z��Z��˅gc.^{�w�v��W���p�A����E��'�"�փ}>`&��1�8[�����z��
3:���XDh���� (}��as�����AT@QS᱑2A��#��Y2H�}���ϡ	�D��+���V�𘭡V0����3��:��7��R�y�8)'t�DLQ�5�����.��� ���{����Ҡ�������Д��/�t����'G1�bFi�Z���{�u`q���aji��{�T��n�	Q�!gG��j��#�!�2�Yhd��K�K68��\��^U[Q0�+�3�Zw�Qڋ�]����3�gC!�c>[cĺ�Q��� �]8�<pT,��Nu�@d�k�MG���h=��^;�K.]!��^���*�&L�d�d��қPnhw̒vk6��Cy<1Ĝw�
�������Crb���W�-p�:��r�'k"%���_1VN��n@��<�Ld����|���K�������l���#Y���ļ�@J�>f�t���Ȑ�^Z��
�61�r���7�C��sOF������L�f��=��;�-*���/������ǔ�R���;�pd��:g�)�,�J'TG����M>�O��#�(����.vf��G�W5�T��M�^c�'�P0��;�i@�+��rœt�bU������gPV���ax'ߚ�S`TQ���^!{�ɰ5�:���b�h���v��G��%��i��qO;r�Q�~	)��E�/�|5š��M��
���+�|��O&���R�h��W��LŐ�;X��B��~�y��H����H�T�Av���;�<����=-�&���� K���Df�К�=+8t�:��P�a�*\Z�AT����1��eG�Z�Oh5��d��z�:�v:�:qó7�T\4d�V;�j��g$I�C^*�r&O�N0�gP��77�?����&_R�Ol�F&�?Q��X��s�9r�ɲ*.]�a�����N�[�M!5���� Ӛ�y�u��QA��7�{9�H
�PF@��yf2��<��3^�aPNc�&�l��_���f�O��`�l's��.�� ��C��✄OP���q�����' �B�$���jY��|pb�(���Ԍ22K�+�<9tм�j��N!H���Q�%r�Z'Tу�2Ϯ�̷� �W���L��l���d��<M��+��~�i!��� 9��p�>�͒w�$F�!+d��ܷ�P,�P6x4�h��ӎ#��������S�r��ߠC����T��t��;�VS}��ޱ?:%����e��B��m��i/�?~4a��H�l��$�i�3��.�Hl:�T� &��|3J�Vb�=)�K�)��1�d��?��h��9���`f<��4x�\=����d2�daD9�|=l�7���<�#5$Z��X�8���kߨ���vˌe�e����3�}l��紩���v7��|LW��S���ɤO�ݠ�%�3}q��Ϥ�-�.J5��9Ix�}Ֆs��;�P�-9RŎ��S��D&�ѩb4�{.��,<
�]Kcgd�M��$�X9�䒿��K&ܘ�KS5��s�u���	C�(%GR�ѣ\8�l�5t���44S�|ܙ%Q�R���%;1!I��[�#Ǻ��?Tm<7��k!JI!	b-�A.]�w��^T�QH�{�k������^t�t��0t+O,7���F��jgqM��#�1��VI#.4�i|��!zcw�����	č#�K����ô�`�EL{�R�F;L����klǂh{�8�I^�$�G����L�9��ik\�8z_^ES����߶��8�v�Nx�y�a�3��te�./̊k\_���M�J߈�7�v�6���� f��X~�Ӣ{`�ݘi3�f≆�<VUA����àL��4�w���K/���Y�r�e������ԓ&'L�e���j������㤂˟��^O'�S�4xS��M��!bPx�?
�`�`�%��\��Bf0���M��y�e���?7��R�
2�W��j��ӐIؔܵ���v�}�����K9��L)6/�\뺶����x�<��=~R�0߁_��@��Ъ�8��E���q�Í����G}��95�2�ķ���Y���+��E�)(/)ƨ���r�F��MYS�P2����:�T�ݖ���)�r���'f}�fu�y0g��K2(�&�����\v�5I�C��/3��˼�c�(CxD۴=��C�d�b�qM�o�`CX�A]X��(��l㙵 R�vF+��D�����/�S)��!��)M�*
@�S|lyV@yvF,�Ax:4�7�B����'뙤�\]�h��39ț�����;���wDݟ:�d<�b����=-���e�����e�7Lw�ɾ�#Q�	>��Rr�L�1�b#/�^�EO�3���{�h�:�W�Wю���f{��g=��k���)9�N�L�y�x� B_g�ᑯ�Z���ɷ/w{�4���c��sȊ��Čy�ŒP��r1Ϯ�1�h�Z���2)���/l�� Υj�gT�:)w���6�e�L"c,�%�5��k��sW<�?����պ4w�U`E$�Zo�����]\h>:�%����m����x��b�n�H�)p�ѹ�p����۪������ᴢ�j�/'\lь�"�%�
dc�k�(.�沠;�i�l�Y�G.v�P�qSC]u����Mw#Ǒ.��~v��U���Rj[�mi�d뼳+�h�� �. ݦ~�����YU �{�=�x�����z>lM���7���ZD�	V�V�F"B�#C���G�+�)�7�?d�d���@Y~�u�]q����E�O��N���xO�5M�c3ŋ�(_�g�?��H �=Q��nj��h�$��B�Lg�����w�J{|��������t�pL�&��� �;2���q���$jߌ+8��j�8��52ö�_��Z�
;����)5M0A�+���V7�$����� @��Aٙ3|�����L�=aܜ��TU����_z-�����*n��c!p�r�*�b}c���m����R+�o����[]Q��o���L*��'�e~��-�ACBA�b�O:��7+���<ܾ�q�֟�:�m��
�F����,�i��i8��eJ�g�m��f(�U=z`!���-ɠ<�,Rg	�*o�����	����"]+�W�c�D�<�l-�pjl6zuQ�������	�Z���gs�"�Ey:O�l ��*���/�2f�@�m;1��-C�1`��A�g���^������K ���T(d2���yH֘I�	�p��S�����DDX7���sMB �TE�.��I�y�]�A@��)�W��j�z�����,ek�'���K�&�휜	]b[R�a+�u}&Tp�w����n7�js�{��B�A�$J�.�<�e��А�<�[ P1C&�-ÀJ!ۨ��K�� ����֛���� �iڏ�jH���qq����ɦr*ׇϗSƵ_���7�L-|v�X�L��+���Pn�wPS����,��$Ԝ蹀
91WYw�H����r��2w�z=��j�I�Q�0_G�a��Ȋ�r�>� �_}c�/�Thr��vbG�twJO¦����:��K�    � z?Y��_H/y\J]��K'�A�qBQ^k�a���
�#�����������(mD�pU.l��8qyV�l(˻�~E����q��8�ϥ��ZWS)w֚0����Ff��ƨL	��������:]����d��b^���`�h�L6U+*���i�^����c�	_����bI���ABm�Q:Bu>�����<�nB�O��'۱F���f��ə"B���$0�/�Z=���Yp�wڔPD�ξ����m����Y�K���L'�'�οBLo��S����V���[Y���d6Ŕ3�B��3T����� *G�b:
�O�b�"ƛ	�A�-��ہ2o�#^�E�����i�"��5b�	����@����J��ɇjV��Sz��m����fZ}�A'�X^�V�hR�ݸ����5���)�R��n��}��8����z0׬M��/���짶iO�(�G�1��.v����FN*i����ƹ�d6�?��p�Z}kpc�e�}3Wc�C��`�w����o��Թ��Ŭ����ZS�)G�%�j5��Xy����o��U�&�Kѕ��6�	��D	�.b�08��՜��UV���G�5��?@^����[A%�-
Җ�:�~����F^z�3���xŽ�[�j�w�.�?�G`3���`�|��
#@k�!���}i�����ޖa|T�k�~�61���� vD�^7��a�3�3�X�!��L[�Y��x�,�?�U�r���/4ih� ג���Wb����J��Y�#Ļة��j�>��ӕC~��wp]X�*a�$\�n��YU�k��n�N�Qɕ��88���v*##��n&�]�[�d�)D�`����ㄅ'���Bu]�	��U�Җ!1!��g���+������Ϧ\L�q�b�0�J� �vB��+~�%�v������RG$^SPTLW&4<�z�T���B�uF�|�'�b�`�,�����c�4��C��;����� 8�����h헋$���
��d�ح�7ł�lV$w݈0�WG����+�I�z����2\a����*u�?��0
��4+�E�Xl��6J��O������A`��YH���͌�hհj�pF�X<�WM�'�]HZ>�ܚ�x�������5֣�v�Lhڿ�u���:�_�����=������hz����`rJV�����A��d�tA&b!�H��-�|'��~������{�g�d�6��	�����R�7�_�;&�D)>[e���5ѩ�\��Hl�ss��;�޾0��{�B��{'��nu��yg��]��9�0�H�)؍1,�I��4���`�L�	�`�Wd�נ�� v?��W$]����x�w����C�\e���u������&P�zO�+^Y����D�yG*d}�Z"����}_sVj�4��<�I����Em$ಾ�i���l�d	�3*���}�rr�6�Y!)��fU/ r�gd���C�� !|H��mOU�3(l����a�N�MmBm�	��(s�M�;���ug|CWP��u��a����#ouD��C҄�1O�>�hc��ڏ����Q�X���V�e����O�\�M�`��x2��6����-����'F@)���-�qE�qOen��KA��gBN0� rՈu�D��A��o���/{�:�w�)I�=��(���)���iJ:D�Eu����������l?/$d���7b��d.xb &Op`^�Q0>�~��l�c���lZx�2�܍^a��E�����lj��^�_j,�#�����'�Mxq�����܅Ѿ�|2���5�,'(`~iN�5�M�(w������]Y,|��v�"����U3;B�R�E�\x�Fv4\(bC(����fhc�r�b�8�s8H"Y�Ȋ�҂�~��)尸HP-�Y��ApU��01'�Tb1d�n�t74�"hv����8���s�\t<J9"�b����#��IO
@�O!|�g��9�(X�S�|N�;�z;	��� 6�����ug�����4��"lM�w��K{f���t���F�ۣ�����B#����7sO�L�)0�Z����qkzI���Ŋ'Qor4�c~�y��^�K�ʃ��_�S^��Vj�.⏳u�Ģ�~�<�	b`[�tP��3����~�]mx}ĥ�{E�,%\7�e����xڔq������V7��'�38kw�v7F2�|����+����o�o�m�}I%��o�]�%'�a���[���?�X�=�}�.���H}��L����{۵C����D�q�Ms�^�y$KZ��-�|Q2}~��F�������i�a(�ZS�oU�ib�.��=�괂\����lu�&�����Fc�mӞ�֊�<�_���幪�H���[ç�($Դ=!	�
Bӣϧ��M��G	?ھErxOX[L���)!Q7�y¯r��mSeF�|l��g����7]�pa��g>�V��9uy�o0m����35� �oF�2�-�N{��ǫ���ө�x4������E��|i���1���Ӏ��~�t�Y�ʺj�&��i�c����S��z���a�y���XG���|Pݘ��w}�d��u�囵�IT{��Il�X�6�:*؂�m���d�+�9���y"/��w�EF9F x�������;9a�!�a�$�I����p)�]�9�q�S�Es��!B�6�T��fn˓�XO����s_���� �eZ�jr��]����^�Q��z�/���
��3���{�x��W�&zL/i"�)d��]��]z=�|"\��G"G�:�f�x���$Т��s�-�!��V{S�Ԟ��G�o��0:�bY�XZf�~?�!#�PѬ�˝\m.E'wU�\�J�5M��\�����d흈��gŢ2:�l�,o���5��3��'/%s� :��T�u�W��yԘ>�t��O�T8�t���5��kշ�6����<�������u��KnS��N����W�\�:V�S� ]�3�}��w�y@��ą4���}e��z��32�����z��cע��d�y�����Q_� }ݔ)yD`,�U	�g'=R����������]�p���Xu�Q#jF��k,)dS�vo j0�/V��D�6��0(��[+y�ب���T���?/���P�~����Iv$R<�H�XN��ו��>�uR� ���!�7y��$z��H��}!N�N�N"ɐ̌�eo��O����\!�a������a3[��7~�~�ki���<��4s+�{�-D�2Ѽ�<�f��(zs��V�BW#�(�a�mѴٲC�-'ڂ'Π����l�K\��Ǳ�Q|0�#�32�0��O�5,�+}(j_�;ܞf[�F4g#Ĝv/	76�$'ŀ�����h��Fj������0TΑ��+���y�R7�o0֋-���pAq���WhZh"��ոV��#3�Y�>�6LwI����K&5���9��;�Q
��u�����@������Y�R, �_�8��w{��-;r!�����`�'��⢇Wj�'���|�иEP"�f���6��q+0n�Q���~n�6�Y���E�TN�	jYM��-��曓i0K�j����\j��LI�TG�^>卭
g�c^b�C}(M9" p��7�5E��W���)HI����ty0/?��>����C�!ZK��!������OP�:Mκ����暢l\@�yU#{��1��|�_:^�����i�%t��t��H� ҷ���S�����2��K�Eޔ4T"K��I���i~�u���U�ʹU;�l?�w�Q�m�ZJ&ԇݡ��/����qAk�T���U�vA���"z>�� ���k��)��m��@��q�@F	��v�p֔����)v�.6��=�&8)g��
����$2�KG�|��,��i����t��L��s@ޛ �3�O�=�`�Khe�r@*����PLi���
MT�[�"t��k��E�6RA��*�[mT���=y��5j�Hhj�X�엯    ;#x�pl&ouŠTΖ�S����n�$#y¯�S�%e+)�t"^B9B�!��9�8[6㽆>��*�B���S�v~q��4I;�bZ�To�9�v"�̣��LX������WӨ�~��@8��Jq(2�Q���$��v�'x*&t��ډ!h�*/ao�4�w��YV��|�l7���9�&l�� �]B�?����m���FrXF]u2S{����&�۫���kN���1Δ�2q�J�%�6��l�fHml�l��>��A˪_V�>q�%��S�i7��+�E��A���Jٻ�������lV�輣����5lS�2p�&��rx��OB��_-�b
}�-訬։�J��R)�bj��=��=q�'�yY�3����v��M_������͂�Yf_(7����f�Y��ܠ�!���),�ڎY��4��r@�M9M�`�h�|�;,��;b�%��X����Vb��1П��5������r�(kQC�D+��I�7&U�.і������$W;�fX��T�y�(���d�xTq��@�`��݃���N�k��hd2k�U����-�MԎ�|ܡ��a�l�Wyk���1Qt�[����2�Y�E4�:AD1�s��rl�F�I���1p%�i�\F�0(�,F�-R#���2�	:���$i�����4!�&�����^��v�ƎurC�����"}O3 �8`�X�������nTΔ\>dp�P�����l�x"`���ٍ2 �5��=c����a��|6�%�:����ڍ}���.�B�����#�;_�/+��M��)<r�w�:4����ٟ���G���)��7��'g����A��M�^����C�x3~���oT
yi�E���c������Ʈ��Z�y�w�*��Ax����:��^Np�Rb@˕�<�=�R(����V
��� 	��z1q�pW&*��K�'�����*��C�OL����Ը����8?L�Yh]9Y,d��6P͇⦥�)Zq1���
���-X�&���1�H����b4���*�7kCۛ��dc{f;�R	�6�.��4�/��J��l!RK���ր�7Y/�E�W~�������o뉔�D��:d����bÆ��3Č�N0ۘIo�T�Ą�-���Ҟ���x�'!n�L�����"��� ��u�$��y;3)���>m.ֺU��	2��\]_l������w��άM=�D
g��L<>O
��a1u��I�4�WE��n;�Q-lߐP\e|-P8N&g T;S-7&�PYA�4b#$d� &	�)��ت����U�HHC�� Mp����/pP��Ӏ��瘗ee"��~�/v��4\�Վ�%��	
�ﱏv�U�'�K�#�iA���[M�R�G�\�q�m�n2o���)L/X	fcZy����1���i\�)���0|�OuU!q��ʐ��L��N��y)����!Zб\�f��0�����i�J")�Pb=q�x��)E�����8���b��0�c�y�
)�o֫��������ժՋW 
>�&堼ƈ���R�o��yW��q� D�:KO�/�����Ü��o�6E�M[��id���i7��r8�JD�H���9)�F�>�
��h4y�1%M@�k����uyM]s8�|-��ܢ��1�o�b�k�������pc��!=�	��jQ�X��@j�rj��5��ka�<���s�Bϖ�_ʘ%�㳂���'KN�H�KG��^�ӆ�R.�Y�n��>��(�2�L�y����BM���*[Ɛ*�~.�޷pl����n�n�|@��ozE�!�Ǚ�b�0{&��z�c�E�Շ�MH]����m�J~�2%ȕ	$Ӎ��3=�*�	���k>MI@�Q���`�i<Z��	�C�k#!�B�+��9��;y���OC|�?�;���9��ۑ4Հ��'ux3��r�h^���SV�7�𗥋��6	�eu(.���)�6&��~������ 5\����������77ߢ�c��$�CsKn�l(�%N,�,
@��m�0�\��h5�Rlᗩ��y������}s>z�����\������+��B@��+F��=��B ���[B�ٓl@����QМOړ�Ֆ)��W�C"$�|~�"�$ H{M:�`�ꗊ��������5�	�~jk��9M`Vh�[�v�0A����!l[�nߚ���s���c�ZI�Ir?��W�
?6�G��lIC#>l��L��'�ƃ������~8)e���x��mƈK�`� C����yj�5�2��g*_��c�z�"�q�z���R�#01�K�Bp�JX �j�m|`�Z�M�Ȁj���,��DjT4Ԝ��},�ѷ3�����x��X��9��ؓI �w��*�h�2��P������3y�����9	�A�=���4}�㍮]G���r
l]�0_Y��f�������(ӘϞˍ��i@�&�#�np�X���B__�dn�7�0����ν�ƛR\�O� %^rif.P�2
"��/�=Ǧ Ó<̚��v�kl��Oݗ��q����w���Q��^ .쐤����ֽ�W��2�@�1��p�����@v⑄������[�fB�2LQ?��.-�����-=�]$�8��C�}Nٰʱ��3��"�X&�|�ƎiF���g���rH��2��Pq<QjL�Կ+7�{��fT��2�=�"6��u�6��!(���(�#��C�[.�R���b�s�{���Z�x��M+̢$�0�D�.�V�\�pR5��t
���\����u��"�w�+�����G��`+ԣ��{���轄�Ƣ2"��5�L	2crB\�)`��sJ��Z2�wְPe-��,�6FQ�� V%�o���z�MN��쇎ψXG8(���l�8@�u�Z�צ>
����&V���a�mH�@� d��@}"s���4+
�w��[	���.Gm�h��1b��(�I�5|z)w����"ʫÇ8,3�ՀE7�a�A�U�%ւ�SsʿN�f?�Q�2rH3I�j�l�3�06WRl�U���R0A~2��G%�t.(��!�+K����v��!�$5D.�cm��{y��7�ke��U��?�@#0*>�T�!�/[Vct�(���8[,�I���c��]$�7d$�r*�[d0�D�TB�5��eF,�%:�x�e�Ƃ�A��Fj.R갻\|@���K�w�|���[���	f����
��^Ҫ߳�m��Ē��P��~q+'���<Zu��&���
H\�r%N��� J
�	nb S�g>%�|7� �<�������-J|�}�n���k����!^P]�n�]��vƛ��P۲!e�-�����fC��>��#��8���o�ku��ԁh"
 �B��۰�jr�����YE����qc�jM���1�V�Y&�U{5�~%T!Qγ�O��1������������]�^,�z]��fp���ͺZ�o��t?P@��X�h�)k[A�C�Y����{W߆L�U-�P	d���l͗���oQEA����P�V�������U����%���~K�Ԡ��4�~Z��%��VE�J~2�3��vr[��xt��2-�}{�@���iP /�೬%���8�B��W��M�c����?4:�m�x��'�ߠ4������]ih�Z�K��	�+��5�d���:�I�0�yT_9���;�N.`=�S���W�����p�~ߜ�c����Y�W~w^A'���{���tvz�֩�R�M�s�AbZ���Ɓ^��wG��h�=z$��k��3=gw�Mԅ�A2�@���.����Q�c���QeM��<�rz���i�X�tV��&)8���.j�7b�����F�ű�g3k�aHnr$�m�@/3Do�i��K�#A�m �g�zO�/'HF�o�j5���|�(�iq��cd���o�����$2敐r��� �l��۰%��q��k�ۂ"p�[b
Q�*j�D��}�Y�T�=��}{�Գ���C����h)��X�T�JoP|-��1�O�U��Wl��z��l��Bk�y0�>VA�    ��S�O�,���램2=�j���)��s;-I�b^��S_�p�I�1�����pY�Ѳ��^ܘ)����Vc%	7�)N�r�FQ�LD�$���n܎S��H� 1I����01]�F�OHI�&$���mPf����T�*H�^1O�zC����˜��� � �s�o�t5-�p���g��H�ܐ#����j	�!��+X~)��m|�g�ّ{	=��|�Ћ(�r���)k�PN��.rI��(;B���&������Ʈނ1�Ԟ�\z��Rë��;�b9,޹��M��N��o�d��>��a��Mn�#��SuI/���Z>?~]y~߹iW��5���^sf�_���ZPX��x���54.���O�O�v�h��#�&M�v�t�*-a�$6t��\�Pr�9]�ܛ��ɰ$c���V��ʩ�"4�?�u|@m	�H���Wg�PҪ��ʩ���M8h/ip�YL@��Z[C��3�R���e�QF�_M�9��k�r�smFw/��s�	_[,".�K���o�>a����2��\�*ꄉ��k��^�mI�u.k!�1��/|ߞ�ZP,6�JWŎ�Vّ�u��M��Sp"?�:��Ғ��Y<���NgWN#�zkb�s�4PiT#�r�Ϯ�3���h��. �,��Ş�nY�"gۙ0�%��/�ԕl�U�<[�z[�& ���lM�����7���:oP�pMs¹k���
��:{>]pF���M�wO ~a��Ϩ���m�a9��cs1���F��\��$���"xz��r�Ҙ��}�h�"�W1:u�@�60K9��DbW�ؙ��sӟ���Il9(OA�����$��D�� �u��$a�y�k;}�xQȳT`���aH�zJ��v���K�!�}9��X�:(Ò�Y�: ^�f����cdb_�,}\�٨4N�s֑�L�]�T�t���������	J�aqu:#�X�/fhP\��u,-�N!\�ռY���t3���ԏ�z$e6�g�b� ��beC���i<)c��q�x���Nߧ^Nx���~��I#V�\H������q͜���ҋ�����p=�{�11<=��cs��Ϛt0cuB�1a�h婖S��&�Ο�;���Sݣ5�خK�C��܈SiC�%�3��	��f�t���'�C�� eVE�,Q譃�tI�!���!.h"�9@��}�
E�q:�"�g*�'0+�;���V�Z|ܨM�h�%%�W������r��+"��Ť���o�'ML��;�)�k��ałm:����a��:�߆GO��ո�V*��KI�A��[�mL}-=�l��'E�F9?�"q���RF��z�l�*`nD��3�m�Q���-)��h3�0���+����fΙ�qK�{��so8��Gr&�k�4��YDג��}�6�>.{$
5O��`��d���S���1U��Yy�
w3�H�Z����B���NGha�_�>�4I�*!�ؑ\z�<�ǥ�k*����}LM�)!��q2�8�����&���rr������2���<�\��{�/�9FO���1��܂m=��7UU�Y��0T}?�X;�������i�ʷ� �W$.v�c���D3 ����GTq2�S�4�ߐ���3j�Ȕ�����s�!xaQ��[rlk�1;C�b���W�gO&���K9ELV�^m�z�͕�\�!ݘ~�i�0�.&e@2e%�΃��JN�X��7*�{htP"r����)喼��SO̴���3�������bt����w��ԼL�����)7?6j��
"���>q\Z�;����)�?��Y/��h�����A�{����f�e���Lt��wOd���ϥ�7�����\� �bJ���kDp#ș�a�<�}3�x����}���Ny]b�H�X��u�><����`�E��l�]N���B����qY��s�L���E�����y�n/o{oL.�|�x�����K�G�V�2�D�O*�m�F��� ��[!�0h]�X[�QP�����T���<������z`1�SJ������nZø��Ǌ��W?gi�5���)
��S��EVx���r�&���E���rV�	���^�����M��0�`>7z-�;��%a�. ����p�:8�-����yN�Hg���(0vG �xE91nrB��0��9V�s����6�6 �14�1�'ڝ��lpL�ڰ �G��[O�6rKȸ��!�p2k&�%r���)�����p4F�n����4��	~�s�EpvB#��(�J�0��c�\��\�6������(��`A����T����j�.��1k��ѳ���G��Q��1�����k�rw���A-���uBWRs��4v��V���iNV�K���!dfMK��bN���c9�(�Ŭ��r3�(c�)�%M��l
�e<�L���T���ϱ��K�Tw�y`NA�*Х��q������f��H�����Q�{��i���;,�� � ־1Q���;��T-EP��赡�)���AK���̡7bUN�2�At�^����LSA�R��խ�4�o{�����ƍ2�	��:=����=�۶�춃��L2�.�~c�\#Q�<��a���[�e�>E��[�Q��`�vbϋ{3��CL�*,�Q��GAg�ޙ��'��M��xÃ�9X�>LhC^9a :�KGrr�µ�׼����f�w��2T
2qr�_����[�T$�XDs�@ ��k������c��M�q���:XX-� U.��[J��B��"k�ի�t�E\%����7e	��z�?٧|)���t��gj�Ψ���$@mҩ����G��g��κ[��L��|W���%�u�%�|��&�5Dy�Q>���7Ϙ(�{;�BJ�ɋ��:��2�o��e��I�I?_�~�ċ�&r�B�<� �%��0/c�e����_8�) �L������
�S#�wa��L�Q(��\�G0c����[5������}��eQ��r��l��*��@>[zX���V��mea���"�S�\������Y�+�S켋0�<��/������s��ې��R�mŪtb���`>>=]��L6��0��ܑЇ�[ʆx��n��6��&�4n]~�����F`?�T����J։,ia�Mus�tkb�����r��,ج_�j��b�Q,� T�	4el(�Ș�j`���E������^$Ò�q�\N(����DB��i�v�'���R�y�G؈�^!a#b�����N3�˱5�⹋.�JQ�H�+h�K��ߑԓ����ʳ�B�4�ɜ�t���7��+8b�������]sz���?!�E�ׇ(�.���J�vd4��{A�i�S�y�\Z�ϓ���N%��L�,���O���k�h�~�v�A	�Pn��}�ԏM3-��t�����?���oEEy��.�o��F~	-��|����N�܅=��%Ν�'1�b^�o�v��?J����Rދǋ=t̫V�s��Z�������->�[�&ᨥ�|�!��L��k�'x'���|ku,4{�2=�
���t�¸����ru����n��]��B�� ^�硄�)[�3{�/���?���9W@�_�{9�{�bL�g[�o���o�����k��m�ZJ���d�m@ߎ��	�>99|&�K�~/呲g_��-�\�r2��K���� f�&<�5��K�/1`:���:�xIb���m|�\�Io�?�܄+N@���V��s�eu�whKf�~�ۻH����D�s�Y�i���p_������&V��%kl�UL�h�JEb����Y{�V�b0�W\@�j�_o�o3��Ƈb�"&<`
�ðb�[7�0����E�K�0^^5LXz����
3�J�(^s��r~�N�y7��C�J��*�Cn�����s�s[N�����*��!Q
S@��`ܭ�JU�u6�?|�Y- 4Ѐ��N�#e,�E��5�ز+�7��2���i��%K�4�	���    [��}"F�ݎ��h`V?b�KZQ����}�<���ٔ�l_i���eR�#���s��4 F�L
p---��E>�i�~��0:�	U$ 2𪄘a��nw��gF�?�T�ەh4� �������� r��0D3��@��`� �Zd$]a�֢���'�ЀH�2�Ŧh��
nE��o��b�o��N�s"nv����sY%+gY)�1�m�-�W�:N��g?X}�h
(�A�E�h*d�4���J�o�W��JD�`'�[�y�G�a�H8E�s�4��t�V"�e�Q����d�|��Y���Q�us��	��*�q�C�ҝփr��E���t]�J�!�;9O�e:�$��XA�p*�J��)��y��w��)��Л�hF
d�u���	˫�t��$t_�l/��CwԚ�7 )������RW��S����Ƚ+�.+�o]b Հx��*�@��ZۍXzԾ�����굉&[��9w/�Ø��B�[]{c�����fUc����ُ��I�Y���1bifD��2�ލk��my�2��������
�G��V�E&�x�1�x�_�}�S۴�Έ�*�yR[�C{��Pa��%���6�gGbA�����Y�P��2,{� ��U����J�b������A�� ��&g���t��!����,���������d[���+2Y������������$w��9$|��H�x4ۇ@��۔8=;�(�6�]���������K2��j��������������"c�kϿeNs�n�.!Ο1G���j��� I�O\a��W����z:�	.7�Ĩns~�p����G�<�lB`W���g�ׯ/��k�C��^B4�?����PN�b����vj��c�b�7�n�h�w+�nl�D�@�U���~tL��tw�� =��MqyFl�2�l>ɔ�s�H;N[^�.�:���CY���@��!#���-��+(���>�\�1�F�.�I���4?��`9l�:J/�i�uS#*�y�;v\� >h3c��I0ge����,�os��19�M]�@����Ii=)	-yW��0�q�o���g�/:7�I.|�`��
)!�n�n�l�%�_H����b
�%�4u����&�5t�D/j۠��q���ֶ�Ѐ����F�k�l{����=��9� �ޙH;�6�e	X��|o �L�LCL�W8i��1eF������_m��e�ň>�>�g�s�I��8�M�8�b����b
m�o�r�כ�§�av�Y|a3^I�<V!9BD��z� ^On�1��(�H>g�-+�� 9����ū �{���8��i�y`����]ڑ8z�L�ꬻ<I4Ypֹz��M��ۻ�~w�7?̘�L����y$QVG�U����W��9�sXKr�kI�d��X%��ם^����Y�[��#:q�?�(�N޵)�i�<�k9�h�|E~O�b���>�L��|�]�dM��P��A6Cܰ�9����Ű��q�9Z!��lI:<�VV�`�6�d((�u����Ȥ�WF�6�y+�]J��~ ��
����ώ���u%gь)�,���ۑ�7�	�����Rr=��k��\h�?�& <�Ȫ�H"8��o���	`�7b�U���+�<�ӣ�Є�]��cq����:���C�a��a�˜���l��	�����\l8���hp�9ٛaE�0�]!�k��ڰg���-��o?莱��8�=��ɗ�&���Fȵ�Lt�#5�J��#������ާ	G$�ᵭ^IBv��Sh�y�'Q!"�|a7\�N���y��/���gxv�7D��(>�)�g}�������;������Q?���9��L2�j��A�мe�6��z�"��7�A7���L�
Vu�?닋�(�l��F.�=���{h���-iH���;���:D~No>�+,��ld���r5����	�s7��s�e��
z�����Y�7:�[\=�wT���W�T�t��y\FlVƟ��F��В�&Y&�]Ez"�l2�]�;t,���5w����2/a�1�1��Zr���X��i�_`��I@�oZD^�ĘC�=���S�$] \%���_����a�(0CA���=4���i�i-�[v�\�xE��F. �m.�e�m�0ϱ�%��d������˃�������
+@ȁdhJ[L䮽
�
BB�G��3���~]��� P-����@2����KA���
��+��*��� � ���Y`!��.ǳ�U��,ϛI����cs<w��{�������RXVN�}<���m�n�ۥ�T>e�g��~��*kO�ζ���ș���v䱅���??�pR�O��^9qS����ɢ�Fa>�j���tF/k��X'I`|G���Uv�y C�����J�/��Qi��'�Zfe0e���9�IZ'�qe�{q��\��'ڃ�٩��v������%��I��Lh\ڻ��3�yA|\jkO��cn�J�����`��p�
/-C)p?D��8�J��$hw%d�i�>9,n*������{k�g�G�3l��F9�����!y5��e�``!�_�A�я9l�+�+
}�g��<f�		�*���mA7�2�����}���
0�)H�ɖ�[���3JPJ��mҖ4�6P#��5�3;B�I],�7\��ϗ��
C,��9i�ZHk����Q͛�kg�!A� �a��IF�a���646H�Vd:ֺ��ohVl5̿Ā͐�	��h{�ўϧ�K�����ݣYu�.K,2BF�o�;����]�]����2C�߅6;Z��~���}d悧Qs���+�K���bp�-!F�i/Q�����J�X_��gL���l�TU �v��Kz��V��Z����A����;'۫��c�q�+�0$x(G�>��XNs�N�T��L��v��@�1A/?��q�\���	E��xSCw�����up�wwS��#��+BO*c�.e�ɋ�i�u�k���`4��sF�^�Dt���g��r���p��U9�"��$�ks|RW�v���Lj�j�p��bX����eQC�A�X��n�)�ROг���3����"!S��^��f5�����ٌ��/�1^wM�xvwDP�h���^��r;��i�r�#d�����a
�@�� OR�xۚ�����Q"H����K6�3�F�gR2.��[��
H�{���x��4��;��7��0Ӿ��Q9��h��O��JZ.Wj�
�ޓ�26bP�l�Дt�����,S'KT�,�<M
p�_��7嫤΅s���V�PI然�;��r��V�jd��B�)���w��e�.V�c^�z��v��J01/rp���2O�Mp= cȪ`�Cգ��"�}��=��5=�z�������Q!Cav/��&?\�51�Ux۷�.*�s/*��7�m�뇕��V��Z�!&τ��v���/��A����o�drV�;�8�2Z�A��Z?1jǎr�"�mPmd�����QB�6����U7h��gHh�*@�9�f5B�0q�g�ln�H�\�3�"S/N��M;�b�o"m�Ra�]<�bÕ�*�k�ݩ5����i	�,;�HY��>5�,���k�ZM�Vr��h�z����B���
!��ћUJ�!�j��ƣ��;�7�.�u�&b%�e�Υx�TWDż�X�Y�pFIg���/9�=��0 �y�!\��c˟�:�8���V�n~�7'�m�J ��wM
#��h����|G�37�(y9곫��Z�넳��� �vQP���@�?���Y(�O���ˀ'�����@�Iuɴ�)�&'9�����`�oMW~�� 2(���L��.��'��.��<���B�0�2j�����$
�M�77��̀�uh���N��7��/��l��������X-����u��AS��l��s(����v��X�*f��t=���B����	��O��T�S��������5F����<�p����iv�l��x��c��h�hR�	��<�F4�����J�;	h�y23�h�[��a����Z��    9�]:�ĄW~Ǥ���m�}
F�s�����ǈ=)0�K=3���<!�% Z�z��Zz0��)T.r�і4���P*�WybO+���Ș�jB�I���ˤ&!V��N�Ҿ�8K�D]K���B�a,��a��T�(�\%��y*�=,~�i�סGR;G�,���MV�]���Ko��Dg��7J =�T�5�����X|�9����̀�|&���J�е�G'������uW��J:�f#�El��B�U;�y�bcȄ%zs���8���?V�oJ<�KC2+��/	�$7�+�AW����&騋#�-�-˷�A����4~%�}u.%x���a��^��C���>%�q�>����q�F$�+���?��0*��xX���������H�-�υ�M�8���5D���l�F+�dF�B��MO��V��7(�	vR�8�7����Ya�Y�-��P���zQb��R)�b���T�Q���R�����F��Q|t�C�hl���s�G>�1�fC
ٍ;��4Ԥ�n�`�oa�[İX@QB�9�N�g���JN��z	#�OI*���T���������]�YJ`�"�d��͛�\�d�J��/ko*{H0E���|�mɨ9�,#��b��� X>k[���B��c!�xv���~����2�˴��7
 �=���dp��ж��M�1�%��G��o�����?���ٵ���iاG�`��}�㿃�:��x������!mfR#9`����ow����i){����s$𳽉��=¥I�Έ���F5'3T��CH���Whŭv�D���4I�]�S�\'�����c����(b
$�Yq*���@X,�q؁SzP��k�n��
b��a�C�.��΋���t���I�M���&:�=�R-��K�Bb{-G����O"1 (��d�1y���;~m�O�� ӳ���Y��nTZRJ��b�jq=C��W`�#e���u���m Drs���_�OP<B��U-����yD�۶q���P������ǫY5�c_}�;�_�$�kg"Ww1%?������#�*��X�bg�+�w�>�~�+*u��0!��&?����z���\�'ׯ�<�4QL�8[�u�J2޶Kf~"�h���J�����Z�]��M�1=���ת��G�E�(_�����b�"�>+�%�[�ዻz�Uj�7�K��R������ԵHc�Vlʊ�F����
�&ww]��_��]��JJIG��	jrRkξɬ�z���-%�xD\"X�M�G�Z�AW��;���1���=<�W��^vX�Tu�a�i�)���*���V����H���"���m�MIoc5
���43�ެbEJ�/�{	���	Q��YN������*h�+׽�[:��B�34F{�X)��y	����/��r��}����*���gV@�d�Ev���c���l�?Qr�	�n����>��4�j�P��s�>���FA2�z&u*�.���� ���]z�IH��0W�lD��҂V�}��Ƙ2/��&�dJh����4��!�'�s2 �x
h���J��p��)�*��\���=^$b^Χ�xo�ab�!��J�K(��B?qx�~}��S.��P�@7����o&	= ��P_umT'���������Up.��6W��-?�-;]n,/M,��(��%6[p��t-�����.f�Rik����7ūp��mv-�e2w�CM$
�as���~.̍k6K�����p��>$\�0Fx��3(��{O���(r�wk�q.X��?R�����W��X̥���"�6U�]�1r��֞!���ՑC=M�	O<_ΉX�e�C�����ј�$K9f���y	���E�c�5]0��j��i��os�rztl`܏D�u�|�MI��o�2h$\k��G&<�w�/&>�iG�5,��:���7��%9�Ps/�(P�y9��ɨ蔛s]!Y���Ҁ��j���U*�s���sey���h��V��A�F����\Bgc�m�����d�f��)m�[�h�D��z9-ϼJǋ�m?���R������Ã�}M�&!��;,��UKhp���i����������-cVߊ�w�-�_��42��V�;�7*��l��6Z�z�P`V��q	��f֝M����T	B�ZG/���3��)V�c����{����
�R�b�,/�;���X�.|+�K/�P-������C�Z��&$�+7�7�/��*�z�72�6^������J��&��!�JP��1�Z�%�>��-n��j�4�&5�L���@ʊ���9���G^���R*>]�x|�~vj�nt�1.�����/���iB�7.�/�%��\��K�x�F��Ǚ�� ՔQ�o�|YOA�u)�@m�q�zV��%��/څ�I�WKhy��̈́+$y�y��D��2�V�x��?RL�w�
�*�������H���E|k��:��&��7�_�1ȍ6r�1G�*��Ȇ���	�Otn���Z1�B-�m�,8ĵ��ڜS��>��ߊ��~>t ���([�+���K���>��w�����U��ɿޙ5s�g�Xo��a��&�T��T�u(� *�)d������v����N�9>���|f�����;U`����M�u`Jj	&��O�I���-A�f�@����[��8ܒ�ƙ֌^]���2��XB+�����9A5"W6h�j*+��=��m��`��#�C�H��G�b����[p�SJ6�
�B����N?�&.�I�bsq*f�3��\1>W~�R��us�bṂ�Ejj�]�&_Jt��x-1^o�"S�"�M2-�NQH�c;�x�Xe.[1pn&q�8e�#�C6�PV��"��ynw��+���K2�T��4������S�:k6k����97i�*V�;!�0�3�[���ݫ�GO -�l���lbuڝf����t��Yۆ�Yh�hza�+���O3q���RVXo�B֋��= ����:����N;y^0���\���@[��������a������W]PX�h��V�Ѩ_SG�����[%��%PLy,�|�t+��*�X*��x�]2u�1=��c�f&03� ���bb��֔ޟ��f����q����˖�6ߕR_����	�A��0��ti��	3���>+����^*���V~�|�zW-l�S�}Ե��[�B6�v���Df.��>Jc���3�\�\��f�x�Eh�7"���9h�1~���GN�݄u�(��Z{$5QT�ȏ�.]\숺F~�*�L�v��T��p�|.4������� G	���Rxy#�cn�M�j=^�θ��*\k��AZe�axr�mn?�dnm��@����)�y�
)�W��B4���\���x�\�B9[k	��c����	���j�}�%�����:>w����h�xQD�g�պ���{���Cs	�~B��f�2��V^f�4Z׻�\�b&	����� ܝ�>�o9:~��n ��\N�h>�0���e��,�su5�%��pYʒp
��^zj�")�7�~��*�N�����.��9L�Z�o��������6 �x��x ;(<xF����l��Ń �G9ʨ�OUg���kҴ�x�+��@ ���=LF/ $�tzd��'NA�z�E$��ŕ�׃��id�)���z�}2�d�|s����ɕJY��� ��[<г������ď�c�f�����ߘ�L�^�j�%�L�2���Œ�\H�(�S<����`�p�Z|]C��#���!ȇ�JF�1j�A�o�LC�T��8��Ϊ��'sB7���-U����bs��h��(ۀ�]oo,0~�����i
Z�1��v�}J���8�G�^��3]��J�82�-�F�h R�i+x�Ij����>ϣ��7�f?��8��Θ��R:#�����ǈ������Aյ"l,�.���.iO�fAApZ��Q,�4�����n
�M��Ў0�lMC��>�|�4,��PTѨ�M�F.Ll����c	é����ɔ"�cFM�����nJ����23��ӌ0�L�ق��]ɴ	    ]Q��A�^�<料<R)l.��a�/w����w�L��N���A35İ�P8J8l��s{�d�:f�`Ty�f�epI��V?u�`�6���Y遵�漷HS�}�D9���)G���v)�@�(�rԼa��
�}�����9ܪ�{�)W��0�-K�z�xF���<z�Vs��+�p1ܸ��o$@%��Dς���ެm莳�i�T��P�}I���'��,64��:9o��,kӑTfQTD��%)���C��74�lk�4�c�8���o7C����c#t��{>Tr���j�)�[=BV^��4CjɑE󜜐c�/}��Tήe�d�-_��q�!�W�Wm�S�ʾ��<��t1:��%}��ؔ�c�H`5G��X��R�������h�S����q!P�x�k�[��`�O;%��P�t1 Hs9�͊�|�T���"�Z�i����$fG',;	ڤ�Ǯ�CÌ ������W�#��a�n�=1D��-���Md�P����X�\���4ۤP�Ʉd.��3w�������N�_�v�]�2�ʼhٙ2Ú!%�5��}��y���-[�&q���"�i�_@&\{
!���f�~��d�3��5����y�[�v��8S��6ڱ{����Dk^7:Z���UwɈ�~Jɳ(F�l��:�]�6G10颂N����M=�~(+o�E}P�����{���t��rʬC�Rvp��K10^�,�����Ex.m`�BSZAS�kf�n���8Ғf~��2��.5i%Y/��͠K��%Ȯ��h���GlIψ!UJ�ڨb6q/�";�پ�8Z����|۞�.�p�|��d���ڰ�	�+\%�U��࠯Z�%ճ<\��N�:o�9�ZK4i�Ф���q6C�j��ﱦ8��2���-E��T��O�IK��R��x֔٪3�̝v�A���%��(�rh���w�,k���-D}}���0m��*M�N�櫞��d7|^�8��O���&�zvC��s���Gy���m�Q�t>yR.�?0��cJ�vض�?��z��������@�Tr�ZLX�^C�ժ�Li�aLBK���!Ր'����X���Aga�\�1�d$_4�w[��f�9��@����ՒF|F0`9�xg���c���+A�F�%�dI?��Z�`�.�'�0@�ӱ��uT,�7��y9@��7]TOS*�y�dK�nS:�@�/����l��B���<��ۿ�yE��h=\�ɧv�fvϩ_˼#2�d1 �s[�~�]iw�՝�W�8�L��x�n��(�jSs{��ц%:ń&T�~n;Ѧ����eP�5a�&HLh��=�E�
J`���D)�6�R㴆�o��엯M���`����<͞pZ��x;�$�1ړ������h�#�9T,�N��s�u�Hh���d�<�pY�ʬ]��D��ܮs�s@vϵ��i���6,մ�3&�����gS�u݄���NTJ�4�����B�?-�'�_ȗ�I	���p�d�o�yI��d�[�_�Fv鵘��M�A���H��	��seB��شA2���^���*����$\Jq_YH]���P�V
�"���M���G{���-��8i���,k�Y���	By{k����HkK��	��l<\ۀ������@5�-~�
�I����,=0Ac;C�D��K\-�����{��B><D�fi6uB��e7�y����kl���qlx~i���G)�*����s�h|N+�$�aNC�ED��ј�����uN�'|ۜ��+�bZ�	��[�h� ���J��g�Ph�^{܉G~,�2�e:�[7֠N���Pl7��&�� ���h9�k��Z���c����%���&�9I�+����o���י!�/��]��m���:�EPl�$bT=8����Wn+� (Dl�S�D�	8�m U�LT:7>�����O6.�IL��u�S�ߛ@������L��y&J�f�z���*ؚ��O��pěXw3���h�+Ŀߞ���wx��`C��f?�w����Ȥ�b���׸)�>���t5X��<��H�$ak��Zm���W�i�q:a,�b��2�w��V6rP�PI���ޞ���d��$��4|��yZk\��K�������*1bn�TϤ?�J������I�-�e��(+q8AzjjvO 
"%�℆-�Jւ��o1���H�I���B���Ї���_ȥқ)�K���siOҢ���?�����������nǒI}O�4��	򧓉2U��BJ�'�S]U������s���n0|=�v��I��%��gf�G�d(c}l"�.�F|#D�č��֣&���
S�"���&xȻ�6wKݾo�Շ�B-?��n7���d��p�S��C�X�09ݶl�7�	ϥ�;�¤Ň��4aY�1�a�����,��c�m}��g?t�{�h��K��R��9�g-p���[�M'/�k,��}p�6W����ȑ�8�5`!��s�Ћ����Ϗ15���N����j{���b�fBk|'�=s�o��_9סr^~�/��;�/[J�Wy:Y����E�2�6�='O$�/d��d]��l�h$�8��	6������ڏ��K}*�]����LK?Pvl2R�S�D�j?ٛl��)�Q�����߿��Z��W�KI�c$��׿���P���Ԫ�x�+ާ�䪝z���Hgf�hOభW��N�|'{�e9aq��C��Gd�P���4P0щF*�>��C��/&D����GAGش'��I�����|�+J��j�j���R�䙡6�o��L�w�P�w򎧽�	Q���3Ap��������|9=��͚�����牓l�7T�.�(������W�J(����BA�����%��O6Rs�m�	imÉLt\!������۳a���d���q����;,���S�t�`?z�3&`(d�����L_�0kw�ź(/�6�"�S�r�#X���-���_�+�d�w�d��D�Č��i-�zQa$/����{|w��D4�vmM����CM!��{��o�L��ļ�O�����'����lb{9?�EY/��1��O��'�L$��D���T��mb��Y���>{D<��o�y������B�K!iH���By�㹰��{���-���+��~���(~b�+ZJ�=g6�d�z��_/����td���K��"+q+&���h�l�L���艐E�D�=�c*�v��4���'�PD �*;Q�Q���C,�=�f����fM�'5<vd���Pk94I�'��������{�)��zytҘ�������t+M�79^X6��W��Hl��di�Q�\����L��	O�wM�������F���x��`H�$_q���bZ�����F��!�Y!�}a�����#Fz�y|��v�C�9ı�{|�/=��~x�$s|bgf�G�l�i���h�{?)�sM�+�2�d_�_�R^bz�a��*(o"T��3$h��$�C.���]J�\N���0��h���~��E�C)6�ȑ��(E�2VI&Ls���k�v�Ù>���C@��a5=
̺ ��[����jZ��{�@�]�J�w9V5��B�Ք�e���h*���/:���c��`>�9V��]�6#4�
�	g��1�¢t���Dق�N-1��uM�X�B�@(�7�9�&T����_��}����_���;*Ȼ,gG4>O�|�\i�
��(Y���Q%r�3�� �^�=�EGQ�h�0�/�h�8^����g$���	z�ڧ�;�_W�ٳ�bDz�7l�4� �|��^�6WC�g��=���F�?GV��%���&z���T�T��qw��}`]@�]�Xg~�I�t���f}��e����^�X���.��Z���,	�Q
s>uԋ� �`�������_��W�F���w��F
X��*}AU��3�EUC��W�[��u+6-�c�բd{"���8QkZB���p��/����v��?�t��e���1ݰru��:���|˙p����yw _��Ԃf�e?�0x6b<��]@����.ϳ��    �}w�3T���l=��پ�����Q'%��� '�*�fə8E��
��	��u��Н�@�}:C�R��hU������W�q��)w_h��$�A��� 	0��SG�Sǔ�xBG��ssw9�X�yvL�Qe���-q��#+�K[�rҎ����n��4Ӓ��#o�u ���]t_%IS��T6�j�W�~����=����4��ͧ�/鰬�q4�Ţ`
X{���I�M�!pN��& }ߖ�7V�ߐO�VNeO.���]�4���l0�,��Nꅮ-����p�&�&�)6Ya<#�<���s�3f(P��9��y��?]�݀��"���Xjk!r��r��C`�U��Bӄ��|t�줹�������BS�VK����O���1bYc��8��{���;!7RI6�'w[C�$���7�\֮	Q#�~���,�	c���g"�DCmھl���w�!ŕ�qv�gj�=����Z1��C�Ȍ��ʇ�+ΨDL���b43���ʵ�2>[.0����{��?��>�W6pC�d��Z����s�۫�8lwL%(4�E���d'$�8V�>�n�R�ۆUx�s�H�,\ܐ�ܜ.��ܚ�Y��"9"b��v�A���r�!���S����g8��p	�`��7g!)�Ы!h�<��{z��p9<ǂ#��!A�����hR~�Ϊn�]�������Jj��=<υw�\�0_5�qcb4g��k��K�r[5��lƯ��`n��V��k�`m?�x[�f��L(A{ n�ݖwKg��'��Y��a�ԙ�v��n�7#�M0�0�.�%��(�������'�@-$��L9��l�R9%��$��$D�����T��K?�e$�0M�+��4��J�g�Z�BЌ��{��O�^�.��AP���ǁqS���̜@V��ˀ�y_h��[�C!'N�����%;0������9�
�l<�������췮�����:��u����FI�t�;�7�E��gy�v:�h��Ϥ����b������3��~owk(@L��:��}��_����Cޓ���� 6����ES_\y��T�y�:gf��
���b��Q�Ǎ\%��#�G��E��� +	��t���~)G�N���b����0�B�^�������R8z��g��&@�7�8��#xx����l����@0�����lZ>ɭ78�^j
�hz�w�8|�{�An�����k%%Yw۰���b��3Q0(Y�~���]߸%>��$�qL�]t���$����mᜉ�8?��u�j�Alsj�a�KCdn��Dy�M�tЎͲ� `%�y'N�=X��o�w7؜��eR�Q晢*�F�]���ʍW�1�W1�<!'Ե")����,4\<M�YA{s��P��@>�lAk�Lr&��#�����)p��\��jf
f	����x�ãi�Lͽ�q�|$W&f���Iٓ�F� 9d��K�W�.��?��V)�bB>u��;lT�aԗ��������>���O��9�rGL��"��!(��j}�͵�o�q�ư�"tR��9�2�c��07�8���\�K+hv�fs	�II�3�5��Q|�޹$�~W�|�v9)�oH�T*��)�D9�f5�e��a�X�D���a�u�,t�*�/7�6HrA斏�+U�c�Y�y�%X$�µ��̇GUQB�מ+3�0�Q�0P�#�M�����Bq	҉r&��t_ZTQ�u�C$���%�D�0�=;}�eR�q�C�Omo'
����0	N�O�?�����`����ُ��s{����%�}f:3��4�@nI�4C�kX�.v�c!��#��~|����1���������L�^����/V[&͹����eA+��<����	�Rc<U���'�x��X��vP�q�Ȏk���C8uk�E�/ħ���ҳLd5U�� rU���c�b��>e�Ϥ�z̶��°����0Z L���	�(�������w_v�Wa_5��9"������vAG�]:��^�9�9���T�
��O2���3�
2u�@�<����d	�ɒ~,����JC+��[�x��i�loJ50�t��rf)��](5ѣ�b�z��+`�'`�0�_�m�vq�+���fj��g�/H�η�iț��aN:n�}by�2� ���	�X�����q��z�jn�X
Q�[+�����pW�4�f?�ͧO����ds8Fv���-��w�?o��"^��2���A���}����⋰�i���R�Lح8��
�ƶz���?�����yNF
�V�������%En�KS^cB�_�z�>ZVo9�ϟ��xmOQ�iަ/��ٓYB(7&��3���pL8=MQ�LTꙊ g�kuЖ�%0��P�!�6pص�"�5_9�t4���'!E�������YŘU��i9�y��`��&��fD_r�U����'-�~R��`(�]k"k�k��謡����r���=Ǳ�	��(�� ��w���q�GF1�����}���-�<�fQ�ק{E��j��"�������ǁ)�8j��!?�2��� �+F�#B�#���t�8���� ���{+���?�'��8����1c����������q����F��K.��w�fh�μy�����1���W�g�U?��.�l�b�kbBv�?�7�\@�
��2�~�u�]�v4�%4�^���X�x��,,`�ܞ���gNm��Vђ�Ҟ�9j�p�c����$����h��ӅFjY�4Mv��vqfb�sw��)3���6�&J|�G
Z?H�U���J�̊P*o���i Y��A#��Oכ���W����7ι'B��Yp����&H�cb��Y�nj�/��.��dt�&���b��v[���t�<Tl@�P�[^���h.��GT@#�Yc$���~�5��8�R���NҨ��4�!q��ƥ_Os��@>��2��k�T��YŝpM4���`�N����}4��յ^"D��q����5�ˣ�E~���9k���l�'���*д���ut�w5�&�6��ՠ��췗�`�?9�?�:��3bW}O�M��~̛�	\�7J����5̐��+����ZO��5���X����|ef����x�@���(�p�Hyk��0�"{��×O	q��+���g&Zas�H�,�KFn�9�2�����Ô��M	�L�4�����*�֍:rC�h4��6Úzڻ��������a(9�W���3�ki������rF�9����ZN#z�ss��,���s�H���1MV��pM��WA��������ed:�>Dҍɇ�Tm&��'c*^控$\W�tC�X��ٰ'P���-�3h�4ʏ������~1�C��T%�q��}��Ij;�K'O�)�i��o�b�_�c�E�p�����ݳ@�*�D!����w���>B�r1u�HS�����x]�	
P�&��C�΀0�����U�R�U"�jƼ<}�9�x	���ji��kz�L;|de#AQ�h��mbzN{�E=~2�>U|x�^�;�b��^�1�yy�)�oa�<����\�ﱺ�����;�k��(�d�S)$͈���:���'2]��rƦ�&��H�GSr&bjH�)r6��}��j}��9�/�#��w1Ffq9q��ia�"U�ͩ��aͯ���r��SZ��� nKxtR.��t��97ۄ��k��������<+�ɰ��zFTL��K��A(���hH��,4�Q���s,`\�(��튦�$v2��0����ñ�hc0M����ΥG��zQ�o;�[+�Ed
��N5��WC�Bݬ��}F��2�`K���C��;'�'p����������w��_wP�~�ɾ�&*l���������KҒ�̭FG�W�9���$39��kp{���&F�"�Q�L��0n6>N�R�@n!���C�<?��ݽ4is��RK��0o�����L�c]����Ljo#~����y��zaBs�C�#f�[D#8D��#Ʉ�!��7�?�ߴ.o    ������3�瓼G�y��_I}'����c�B���F��N��=� ���������?�c��j�9��ޖztñ�(��}<����苛�A������q�mf���r���@�B��c*�������}�o�;�O�d7;1�|�Y�5㠦wT��$�Hާ���&n�	��m
�i⽃,v�x�L7VL��L�1�o��p��N�G��e��0�F&��8lnƲ^:�ͷM����̑\�Lv�)kE�! eiJj+Y{	�=��lDm������h�!����D����Ǻ^w��zvm�p�.���W��'t�;���Hp`���TC'��os��~�{�!KW�h��@-Mhb	�Xm�|������j-��t�|�o�Q�*W�	����k�wx�~�@7�}��R�T�b� �q�!��Agw�&u���������"��I4��saU���,���pn,T1n��s��wD�]�c���
0�.�l�Uu�m��tٚ$U�\O��^aL�lK��������{TOl��K�BO�3�W�5F��U�������!RB*��/&eg������ �#dTVO���ys��ʌ:J^e��a�⏭��j� �� �A[��BTc �u�PN��0ђ����QK�D��`�Y�P�ǋ���Tl���r�60�v��Nm��l���
�����`M�x[C)�0��U���-&꼛$ԭ�8[���JκY��p>��Ȱ�i��W���F����U�}��DUXsV��W�	z0�C�	~�����8�q����lj�^��u}��]�|�_C����u�v��ܯ��W ��
�BJs�U�l�M�W�~
1�SRp,�P���j��͘�[!Yh�a[&1{H���ﻯ�M0�2t���>������i�ǱYt�*��g�j��G�	_��M�g)�Q?^0�F��2r&V6vP�v����en��9��
I���4NN��k�8Ǚ��d�O�Q�+��p�^�W���p"�o���L����?�Ȋ�f+�G��?���C�����Cu��y���vR����c�jm�����E$M�MH���H�1)�X���E0:�tB�]z�)�xwH	v���}�5L��4�����:�
=~5ڞ ��>���ew���m�b��c�ը�^��/��^BJl6Hhn�i_3fDr�e��7��qPZZ�~�\�mBb�Z�)����.<�ZSߌ<~<}���	��|�n�>�(�d�A��T�K#���"�V��{Fa��D�w$��z��	��Ƴ��w�2B{oq�/�!k��KM�L)j�I9�T��I�@�b�X:�7�	1��j�'*ZQK�!g�U巧����ڨ�UC�G{�� ��8K����W[�yH��
��&�f#�2�,���{���(tv�1f���}���-��[|��������5i���mD�6$�$�ëPTʙ�J:3V�$B<�O�x"j��U�k���G#�i��O����h��A�aԾ=�v�����_jsJ�
7��	��q��&�a�ߞY�+ml�0˞ʵ���;�m��B8R�98�m����:�?K�0�HE������Иz3d�!W��Ҳ�FwK��B���}Y����)Fцu�a=<���`N	��պ�K)&˹�n�8T���n�&d-�����*>�X���E�u�U|�ѐ CUa����yKg��9T |�^k�1�Xj�#�7���Oԛф��T�l`)����Y�,n�"�ī�x=�~�����oo�����'��F0�.�R�+����~�i���"��!��x����Vl�Q�^�o����]t�'��A���MH��:Y��ZǘG��ת���<8�1n�`��+����'����g:s��x`$�f�����~���i��ұ+>c)H��l�\L�j��j��ԧ���.K|�o�g0!G'� �"]PV�+a��mP���
Ê�R���<�t�K�&K�U+�wvRS�ͭ�W�y�����`y�m�x����d�K˭�L��d��Z�*��ɨ������f�RLI�.�2���I��O�J���ɓ9WV
B�����Ip�R�~l���\1�J�'6=ꝟf?��Y)]1`�]W$f&=.�7�.AW��پ�`nؐ{	/��97{�K���0F�!�'[���;aߩVe��n�>��&J�)h«f�zOn"�\<�_��yª/s6����SMx�͹`�>���/y�>>��
*����	�Õ�ox�X)n�����5��[9AR7SQ&��&Ht�4��0�����˸�Q�'��*r�ѫI��mu$��.ȭn\t���X|�R�a�х���w��J��,�m�0��M��@��]C9&��ݗh=����4��#>=��ă���T�M�b"i�
��W�7�����	U��]I�v` ��@��_fOV����f"P�8ؽ)µi 1"�Q��6:�z��;ĝ��`n֙=�,^"]�0|���+u�V���z���^��6e���֞I��	�	i���	���[��$M�����g�id�X�ˢ+Jgg�v�z��g�E-w��O��x����(�)����Q50p�� �W�@U_��Ҿ>r�MN �p^�Jq,�I*ij-q{�p�QS{~��6&~�m�w;"h�,!�V�'���АP����*[�����v�XT�৑�%L�|cĩPux�}����=yM@�.K{f��OM{~��3HV�"��Mb~=�'YK��Z���:��dr��u�}"��Ĩ��F��[D^F@a ����\r-kZۖ+�0҆ '����P���{1̪g=a��f@v>#��/	�Pn���{u;\�A�90e�'d��Z��ߋ�\�����%�WA����P��9��ns΍�	�����n����"�D޻��8bDX�Р7��G�TYO���Jh~р�ck��ra4e>���at��n�6Q��$D�l^+i�>��`h�f_Z*	$�(b���ҵ�+�/�ӕ��#Ǉ����3��1��zF��CvZP�|��!f��+�&�ot2D�
.fDI�:_�\����+�)Ş��ol`f�_w1���f�cx�Z�Ƈ�:;u�j��ڴt���j3xVG��>
Ey�\�@�8�p{�/t����m#U:hי�X�De�rv퀾�X���(���ʋy��!	�����B��3>�c�V.7�n����)�WIw�dE�U~�c ��U�]=�z1�^��;!��E���R�X؃�9��C���$o�Ĵ����
�iQ�A���z�PRy��\JV^��>*g�19��f��5�h��;�Z�������*���O7D��(4<�^�s��Ts��8��Hy&������e��8�=E�h��y�9�6���N���ńI/q*�Bxxn������:��1����=z ��Z��T���ꞈ��E��,��k��QG[������ь����n�����:x��x�09��Iq�⧰�Ԍ��ۆ��E�}c��ڛR�ҏ2�kW���r��ү��!n��g�!��`�A����X����LB����j鮞J:0lNMOu-�r#T17��"�L�bj'A�7W.�o�}{صO|���3P��:Uډ��0�Q���	��4.�sg�!�h�ψ�{]����R�*ŭr��iy�����|$B�Z#Z:�8�o<�3��i��u�Ħ��-���k���ɢ�%��U=�g3�Z�1��"s����dW�o^õ�L)F6�x�+�U� r�HAYv��;x-��nʹ�O6�쾪����OPQ�LG�N��e*ҝ�贻�R'B�Q��Mۦ6P��OR�_��ֹ�С�U�W�8�[���	���\�"� ��������?�������3�hM|&�������_2��)Ɠ�%��D�Ϙ0������byY��h��!��]Asc��H�\4��^Cc��!&����}|�,��ߛ�U��`�O朧��JT��d�0��a��%N��b8ONke�TN�HD�D��ZY��d�m�zm��[I�هñ���
qbY�����"%��LAhPSJ����Gq��AZa�M�M��� �  �$Di�
�V�>?mg_����e(���)T�<ދ��t14T�!����GaTKm�bU��0e�.˔�l`�G��*O.p.��q������_:{�	mO%#��a�0��OiUN襒�	hvg��5r���"	��\��bM��֫�w1�vǗq�&_ۏ��``�\���#�(l�7K��C��f��><�
�iE:Ժ�r�O�+1�w�y�_�������,9�C̊��y�9wٰM��Uۙ��}��%�eBȏ�w�0�j���D��L�����;gs~�V9�)����م�gP�R})[i��[%dۏ�ICR�t01���E�%̄ۆ���"��XgܺfN<A*|,R��mN��q.L���mK��r#A��0��+�`���54N}w��>����7�)/�����#��Ԡm���G��N$�"�R��h]�[ƨ1~	EjS��q�m����¿=�"��9��q�«�F��������Vޤ��*��eN�]�U�b��"��H6S���h��*����fS�`�����X5�l�_y4�
o���!��(�=�I��Gr�(6%}�����e;���	�o��=����Kx	#{
B4M,Pb��Qe��#�&1�.�Ϣ�FM�p�/�5�gYX�y���,�V��qy�u{W�߶g�^�NP�ǂ�1�+�v��^da�� d=��*�o�<��h��i�u6�r�[]��y`�ĸ��eF��
-��ɞt��y$�Sq�́g� ?'a�S�� �\Bf6k�C��f�i�!�\'�����+2���ǝ�Ґ#��٥�f̉ʞ?��٨g�;��+�<�p0yv��M�Q�������"�K8�,q��@<r�Z
��h�+ "��,��ل��p>���8���'K��T��n_@2T��\�8�e8���>#y�y�/�{�=�ޚ�%�MpA���DJ\ЦJ� ���NtC%E��qYLM�0��CZ^��(CS�!O�ȋT:6<�|��~��dd����ގ^O7�	������~���?&[�#le��/t�U�Y6���������/%���1�MiVhYK�K�(�h���$�8�/�1a����}m�������lR����j�z� ��ēo&,�l�'+ȳ��;�>*sm�\7ea�v����ku��gF>	���Y�%b�k{?�iPH�ƅ��nD8b(l�Ø�A]@P���O��>��o��Dh��L�5E�p��=:`��a�l	�N��̧��>�g�����Y�m��X��֣>J���[k'��;u^��C6�kp�H�w������E�B���l,i״��3��&�7�x��oF�� [qw��:�H�銞o�gV�Pb�(o�t"�[����i���`>>��X^{�0�0G5	���<�l;����!¼v��/�l�4�S�?���^K���ɮX+�A0RԤQ����h&�1]s�E��ܹ�pu'�-dp�� $A5�p��=v�ɍ������vg�y�����󍱵6������|9�]�&�u�����6�b;˥�n��`�!s�I,��iw��!�@QJ����D���K��4Y��@͝i��(-�AP|�	���]���L�U����Z%��V�Tڹ{z��}h!`��W�Si���c���(��Bbʡ���Ʒy�"~*���)�-(��]GB���pP��ˡ.�.����t���o3w=�;3-'�3�K*~��UsA/�Ǒ�;���� �Tۄw�hG�Il�v�����,��?�>9�?m,`,yh����,E*��Ŋ|�Z�M��Pg.�����L�[�Ɂ���A�fBj��������O���#5Exs���P���KkMbL���(Z[L��'c̐�Ya8�2,%�>^.~��~�����]~*�w�\�:J?��T���������";��o�q=�Я`,p.LK3~��g�/$����a�m�}g@Kp*7���%��`�b�֑�k�-�̘r��Jj/>�p~)kѶ�lT_����*h����y�<<%��X�i��
�	ECf�j�.�R����^������ଃ����ל.X9*s�CX]��I2=V�lQ�m���T�
cj��b\��mp*V����M�T���s*�:p�Z\T�}�v�3r��'e�,����:ŴyU���.R퓐al�"6���-q'6ł��Z~Ow���2��f�䴊�N�g5�A�}�ܜl0�wo�d��]rj�(���`^Y!�k��A�8���=%G���W6�p��t�V�U�R��_r8V%���QX��o�y�N1�g��0Jݰ�m9�Dȫi��S�#�ن�OW!tY�q�?Bl�n)tO�O�u�d,�v&n��A3ARhbt�
 �� 5O�A#V餃��4�Y�5�x�e��_�����-@��=C�9�Tl������B�0���(��0;ש�<���H���Z���k��X#�p5��΍`��z����~���o��ߵ�!n��K�k\���x�ۀ+�2���ɶ�0;ផ�?��n.�f�y���k�b�=P_��	����ڬG����	3�f��\˼��c��7?�*�3.>A�G�a���Ê� 7[bB�J>7�]�\0!Y����pXf�P���eD�-=2)2�]�4�"(��L��$�K�n U�i𘧞'F�x�#�l!�f��R�t���ZE�0�l�b��6�K=S����Y��;�~�¾�(P3��C���O��G�u��A���n�h��A0 �?p�dl5��h�@���K<r��O"Z����?�ܫU�&/SЎ6J;?4����n��7��
�^/Q�W+����j�03��E����mP)�4z��n틮���
&��5��t��#�Y_}mx�Ur�=[�,�K�mx1�y1��ڊ���\��f(u��pYez�)$�qK�&��
	렏�6����E����{cg#0h�����+�d�� V�;T&�I]JG57���/R����� |��V��5(
A�&r��Dh	�I��\?6��������Ӛ[��A�5)f�e�p���+w��}~�K�EЈ�)���0_�� $��'ܫ9����[e`1��NMT�K^�m�n�3��]��#w$�c9v7h�xÑ��i����E�"��H��y��9;����3m�s)0���)L���٧֪�?��iu��PXs��f9S�OИn1�=�.Y���rO�*#-h德(��-*�{�Tӧl06�R���@�)��8y'D+���7��9�@օ:��8i�?��)J�b�H����ҷ�V� �%�e��,E�F�V�N�	c��W�6����� Q���4,���ِ!�d�6(i�-�G�]h�������nO]/Q[̥.�}��ze��Z�r�q��31�r���X�+�sS��ӥ˱6�}��>� �#
��K�����Bve|�%�,W�e�����p�*�v��M��V7�Ί���b�[�H���d�q)8��N���\����쯻�}ϵ�s�A�	�V��%�C��_N[؁q�����F���P�����
;�>A&�	UYr=���1��ǘj�]���Z7�Z,{�TE���.�Zʶ��������=r%�M�+n����Yib���Q�����j�T�q�#o3MVc,M"���x%�/�.){��$⥐u�G�ڬ�l��&����sߝ�w=\~6��J�&m�S�5�Q�������0���h�#�VƷ���T�I�aV`���r�p�i���><[װ��N<R�WqI��J������ŕ���<I��>���o:eL��21��s�X\��X@<�~�����Fyk�wB�u�NP�B;�U���E�����7�(-�
B���)
_ɉScB�2�����ZM��      �      x�}�ɕ�rE�q}+䀴�$Z�"��P\�imL�,2A��h������������������������O�<�C���=��	���}Kdo��V�_=3~���Mo[��?=��zt���������w������F��,�o)�����=E�gisy�9_��|���yS����kE;t����u��"݄��������ͮ�^�޶�;���� |?��7��YzՃv���X��W3���{�ij���^���|�u>����t����\+��Y��zc�3S_���ok:��ΣVs`�=�����˚fZ�=E���e�����O�ȶ���������������v�"�qӟ�R�yE�s������w�����#�{Z���W��;��s�ߟ��0�{Yj����^�����v�E�z�[j�����t���cR�(�E��6��������I�yP����"hu���7~p��e `�:\���"��E�?8�[��:���y3(����] �`��:B�=��l�E��}=u��;�����>pJ�����6!M� ��m�������{��ڈԙ:�g��zF�U�Oo��@g�,�\�3!���,L��m�H�	��ٿ������B�^�K��U���ZZ�\������"�`�-^k�`1.^Q�O�4]g��_5�̄$Q��*L�,���El���u�x0sB���"X��KHԂ��t,�>��ٔ��`t�l��|�?��rQ��c�)��S��]ۑ��8��@�)�YU����T|��T���A8�
}R���n	m�/U�:�</�u�����@���9:�ߥiq[(}�A��1h��;A�L������a�.�Խ��R���^H�Y�� M�B� �(�1�O�^~��.|�w�����~�Ԗ��N� 5��Ѣ|�.��/��h�,�����{ ��v�����>��A죷񩯱��� �W{�$�'&�P6� ������
�\(���_��F
Ab
�_3F��v�t:Vc�"��b+A�
i���T��3]0���_�i��̂.��.��Ԡ$9����R�Qz
bot�܏� �ӟ��gh;�jm��tiE~T��b�/����ɔ�b��'7/�BZz1i�
A�$9�Q�p�.6^ʴ'�-̍VG��4�Alas�6m�An���V#&@?th��ku1�J)$ɺ��f3���B� >1���*� ]��S��M���^D^/9m($?���s!͙���QP�{���:�$�i���i?)�������g��)������j��,��L(���Uhp�mI�G�fP&5�1Z����?|s����^ݝ�Ѓ�$��� �ק�4�8�I������]��tSA|�Ԍ4���i�u2����X�ёQH�.�E᪐�:�2̵��z�:�.�UhbL���1;�_ȣa�RH��ꅆ�|�wJ�c�d����&���*�4���ܠ,d��c�e�Ⱥy�	����E?���:��gm��Ė� m5��pD9��o���N��(�/o�5&C3\|Ⴑ7H��*a��ؚ 5�����T�� �i�I�B��M� ]��O�m5H��B�6�/�d���wh'�'L�A�0�4{�W�� I�1���^��r=�������1�K� ���W��/��A
*(�C���m�ͷ�t_����Al|����ǃp�� �{fn�熼��wME����jcf�V���t�A�'&M(�$"A�|�[��΅���O���}!�rԾob��`�π(�*�-��Y�Lh��|聟��3��O(�����]�dx_���4�Gp0�N�2$(H�B��ǃ�}1в�4{���LH������s!7�9(HS��N����BSG�%R�Է�ZZ� 0��&'���jEt������������Ϊ��~�,��k�m�� ���A��AX@��¦�y�|^
��By]��d�����5�2w���qP���
�� �AJ��
mO�-	$f]LѦ�鄯�(:&H��Y�����B:�u���j��q�$�VjDZ]э$87�1�\ݨ��$l%����SMɟz,$�����ā�<��n	>���tbҴ.�ki���,)o^Gi��{������;H"M��|����ӱ���`��Φ!�˼=[]���JҔ��l����`���J�1�z��!cd��P᱅��ѡ>Ҕ����C���l�����8��&� ��D]r,��ŀ):l^Dkk*�<oSz�IsNf���j�[�iI&j�_%�¤X�t_�Q(�m��<����I��q�A:X�WP�;�QҲ����`2��E���� ~2WФWA�E�A�>E�>^?�g��\Z �a�=�G���nՂd�� v���v��OL�B�'y����7�N�e]���@�{��� >%�� 	�t�r��$ᾐ��b�1`�,��m+�6#
���Bӷ������IXH�q!-��+��=w��M�/��I��em����MB�f� ����b��'O)�7Cr���
vB�~2E�J���JI�\�?�t�(�Y,�H��$i����G�׭ ���5/6��,L��&�MA8e҅��R��G[���B�3� ̋B���B΄ xq)E\�m1\�i�C��i3H���H4g��_�њL�j�뾗�� �LAJXHS��v6� �q���Ana��I�2�H����j/mg ٌ��ڑ_f��^�$A�������YS����N�Av.�A�;����\�rh~�.|�|��G�c���c� w�Զ�1j,�_bn�]��/�|��-���5�u�F� \ӂԾF�Ш�$�5�W-��֜a�1($�O�Z��:��1�=�@� 	��_�N�C��
��ۘ%*� �|��~�b�?��� �H6����S�{b!y�ĶO(�>g�<���:"��}�}�$Ѿ5�5�Oà�0��Bi��B_�>S�izz!��b2�Bʥ<���kЍ����Ƚ!�oе��-� ~�\�2uꎚ�F~���0�=%f�};���s���'��6�L@�Ȥ�n����_B����8|�t+��e�p��s>��%�f2�F�!ṳsz�N�I߁B���bbo,��w��紞A��b��������e+G$�p�(@!M�DΡ��W��.��"��E>s-� 6�I0HnP~�҆~�"�6�EUq���k��H���|6�i-/�Xv�	�"��vMP�E�Ƨ^�1s`����O��M��v�m]�f�}�;���$�/v/5P���A��Al��)SC�fb�3��B�kN���R�G�I%��*y�� ��TY㗹1r@��Hb��&����BV��e"���l �d���,ꝃ�4nA�Ӵ_�ڃ�����K��7�J��|գ:!h�#�ߖRl|��ʚ���4c@A�&��rl��~A��*���a�.$� -�-�9����8cX]'�/�1�� -����)�O��!?�}1���s��)���ҭ� ��k�������P1�aj8�.V� ��A��K�OI3�Pom^��/3��J�R���n�|����U�T?�q�����)��9b0H�j����S���?6�U�'o+_��A:�1�6H����I��J�>�9�Oi�y���Ŵ9讐r���Z�Klkr��3:/Z�\�p���96-H;Z�S�O)`(H׏K!��?U�k�M�M���������4��F�� (��d՘�>�F�n!�1���$1�M:H����j]�E!���bD�{;=�N���?J�E���'P���l�A��vZ
�4�������A����H��.�Y��5��:[̺l��$��� �'݊�N��6�N�������	��U#��g����9sh��`�tƥ�`�	�,��5H�W��<�{�t��(�B���i=YQx��S��E����	w��k�p+a��Zmi��6���9�A�(�=�O�(���i�B���R�Nf��p2���#���A��e�߲4Qc/���N����ڂtp-�0��B    eh*���-�OL��8�_2Ii^'��O����ARL�0��d�>^�J�ߒ:�H㟎@�i^;�+�a]H��fu���¦]c��Y�����0AY���}!)�c��ǥmV;�� `�/��i.!�b��(�bd��K� Hk�9B�Sk�T�=a[�/�����T����#A�j�K�K$� H�:(A�/UE�PHJ� ����U>� ,�B��pk�-���&�� Du2�鏒����YA��4�S'u��,� (i�6>jz	�d�I�&��ԢݩE�)�t!/
Һ{���11�T�7�ݫP��a�@�
����x��#��kO�Qt`�g��N��RM�x!u���m�:.�A�ށkM�SAP&��
�AZw/�?dָ�6D� \jK�32��O�|�G�Nnac�d+��T� =1���s���'�(_�`,���1a{�D�I�
���]�s���?���)Y}�ܽ[�g�fΞ�G��F�J�_�i蚋���!H7�ƨ��X�"H|��Jo�
��4HgZ�s��#�]=�2�w������u�t�6�&�Ϥn�����,��v�YI�����s�LgJ��� 7^:� m���䌕��N��B&� ݂�G,2��S��`�� �q��R����Z��Wb=�U��*HB�Kt��
�ƃtdĤ�Y8�s�;�e�և Ix�Y��w-�\�e#z�29ٔ�Fj��\�yF�gb/���I{K��}ZÐ�Q��20�ܚ4�tGl�.��L�P��iIx�{#Ƚ!���A:j&��<7���93ȃ����V�L+�R!OD�x19H��b� 	!���2��B9�	��R���X�x@-��.u���b�؇J�y;�KgQ�F�uY��x� ��d�U�+�W���b�� i��[
����`�\"�+l+���ɵ�~HG̊�b�S�w�l�Y�(���P�� 	V���r�D�}3 "H��a�d�G'���dɧ�'�fb��v_�g�n�N=xy��=�;a6UHjA؀�)K�p�� ܫ�);{���A��� čd9e3t��_ji� �y���	B }6��:��א%��Qǚ�_��|��RZ�(�Ԍ �ÇW� M쇾 �{Oч�/�>;��A�Q��bo(7�M����������4m����ЂR��Al���5�оWq㕐4^F6������ df��'H�TH��,4������Oiz����On�A�9���%�� �YHw� m��A�v����)����J
�2��Њ�E���=}�.¥��j��f��B��	�v��$u�x���X� \5b�r֨��hJ2�G�M�������zA[c�d�T!7-�rt]� ulc�M��A��=i�p�
Ҿ՘T1H�Bc��Bʧ \�p��A$!#�ON��AJY�kߗXեT	)y4��R�SZ��3>�;Fgj� �̓4��������6H�?�O)W�A�di@����'ˏe8}o�'��~iI:p4H�d�j��?$a���V�hTGj9�3�]����L4�+x�*ͧT�'�� ��i��KI��я�TAn���
M픃�[�� �\��zM�E>%� ]N�Wà�z��A�H��DR�H�y��f�d�� �������{�����Ag8�4�������4�?�T����ט���7�ɂA�d,x�$v�1c�1��V8�O�Y����HF]~Ů�*VA�/�?���On�
i����H�e~�/�y�,�}I��f(o�U��­"���<#�`چ���N$�ɶ��$E��|J�]6CiD)�z!�`���'�)mC)RI����k�2�L�!����Ul�9,��"]T�3���B�L '�R��Գ�њA0���]��$��s�_�3��l��� I�Id3������]���M��1^H�~AHP0m��!Rp!���gA3�;��|�Y4����zA�/y�iҼrU-"�>!4�ӱ�A�3�p.��ZA/�#����u�%��i!�8	��0�9uƈ�A~Yk:"c����||��Q�K�O��!w� ���\HEpϘ�)�����d3�7}�Auf)#H+<�=��u�`7�C�9�-T���1�;H�K,fLp_�w��m~>u?FA��=�c
ǌ0�v�FcA�N�F�3���`�����v\h�$Y5fH�Ac�،ŊO�4�N�A�)a�%�p��E���Qbt�� -�Xv9m� 5H;|W���)�t�����ʞ�͵3zu������p��䧴\�0Z�$:m�:���|L��J&Hyg� ��݋�S�9�.tո��E��h�E�����u8��NJ�Q��`H�L�P��i@���9X@�_��GA00���Q=z�93%	9Tr&�/���A�.���AP��y�>L���f|�7"�|$s&[ ]F����A>���i�UB��Ye���Oj9�4�.��~�j72]z� �,�5/�FX���*^� t�(�X�7ȟ%� �����,?��H� ���+t.��=�p1X���&��n�Y�I��kI Y��A��/$��6��]2>*��������k3�� t{�q3)}�r�$�)����4I����M�ȹ�e(HR�fq� w�R���XH�����s���U�\��C��<Z��P��� �A8�#산1�_��;�/�<�f��䎒OW�Q
A����*�u'��� ?�<A�n��y���zTlt������2rd��2���@}w���H��zxd��9���܇rT�(j�<�� 1f�q"/�����%W� Oi}
\��S��RS��5�� ��YC�í�z�E^�D�<�	�R���@v('��Z� ��/����$1t������zi*X�zY�&�K�,Hg�[G�k��|��K��An�+y]��� ��C�6�l�"�r-�v-�h�&��{?�
�>^�����tXcn��id��Y'�,?��L��r+HR|�^z$u0|��+��� 8|�o7� �I�u�t�~��r� \\��FWS�"��ж�M7�� �i͓��xj��s��10� t{c� -��x��<���A�Y��ZGl.Gl���A�.��X�9�
��'HT97T0ng9�4���g���E��1��VVJe��ZY�>v��:�B!⭐r�.۾�$�94� vT�Ƣ�}$HHg]�BC��E挄���Lg�� �ԝEt�+vf�����s�d��
I�)�):<�%��ZDA�%^�5>X�k%��RH;�`~�5,>�v��o:��7�ús-[�-);b�Q��̾+�؃�B�O%3]�K��lA0���/Tɹ��YӲ��=Y!0ȍ��F�n�����d4W�	���wQ�pe!eO�(/i�c��@��Ajx��b^,��e��Ӱi{J(�L�A��b�Ŕq�^�.'������b�ek��YRDEł�O�d)JV��i7�Le��������	$�ж�i{p����6\.{$qb3B!�R�6�}�wo��  �4��A��m3춭u��d6� șA�VAKs�ߛP���˩�!�t
�6{���AO� �W�t��:-�=�� �IU-�xAP@A%�m�n�E�o� �Ք��*���@ ��Էk�Ac��HK+p¡v���R>��(�n��򻔜�����LR6����Ѓ '�~4&E�=�����A��tVF���iƂ4A_��A��m���_��tt��%�j����	���w���s��u$7��U�P����A�mR�~<k�St� �AHD�ǃ0\=��ǘ�m�]�x�����QHޮڸ?��A�;A�(NÏGAZ(����փ�$Q�c.� ��O�Fq�)�i7) �6(σ4g������
i�n�ލ%�w����n�����Y9�� -�F;�n>�3Zi�&��͐5� ~��p2�xU9	��Z�%�����+򩈶�.�����I�)�M����1��
�
���� �o�y�c?�3���    �Z��)0�`��ݶ0A�����L��=�]��J��cFd�.m\���^'_(k��(���{��3T�!��m�L������$���� �	��������������;H�`X8LI$�4�{��6HBߤgn�Ԝ�d�m��n2�;H�D'��xM&Uۓq���O��R�Ā�f��9Y�� ����9��'K(��P5� ���גCҎьMX?�ą��b1� I�v�E_���A�ȗ�� �)��p����t�Anᔖc1A�.�5����������Ãt
��V����E>#�~�2�����Vn��Id-��n���;�|�j�M��A�/�p�^�|���kɞ�p���=l�0�	��� ��XEq�>�{����af���	�!�#]�ҫ��T�?������p�� �v�O%���<~�����a��	xإ_�����}�T��7y0=����e�?��~'�C��a��ȧ�����x�)��¸�<�r�7z�=��<���a��1�L%��a{S��p���<?e�=��a0I�c���{�A4��*H��̯�\���n�2��Ő������.�����߇Ax7������}�K��?����0�D/���'W��.�L>�a�ƍ���0�a2?���a��,�X�z�0h���0J�e��~Ԓ�"�&v�o�j�S+�[i�>&�8�+%a��U����?�~���9
�à�:�B�ǚ/a��Q�|����àc=�2��sa����&[�a�]����8F�b�52�x_J���Ai'f����X����q��|�K	1U[/}�+m����`�<�7
�g=^�A�惶Q�y�ԇ��Z��2�e=�?7�F��a�y��u�/�G�K�����;@
��]��������4��_N!����4�:�Fv�vy�,;&Ѵ�LJ�0%n9�'F/y���˷+T�0�J��K�(e�?�v*��aP@�c�vr��d�Y=~ޖ�Y������Zh\n�y߅qs�s�f�`���`�9�g�
.��`9��lЅ�0
�Y0��:.��`��?vy�j��|�a��>�B�`���T��8'�a�Qv�כZ��C㬃��x�˲ӧOF:�c��z�9��F�ܼ��x�NV^S��a�9�˶���.mi�~���a�Β��L���d2���˴���aTLf�9K��O���+��h�'�F�׼=�O�q�L���2��L��~��G߭
��m��͔����JQ�
����9Շ?��N�N*�jt�i��b5����a~N�<�A�.6�$��+F17�3��3��Sq����.���0���",V�9�;u��϶o�[�A�6���ms3�5�6s3�]�j<���h?��.ߧb��(����)��4�A_�o_�wʹ�0m uG�D���I�|~�����ävMK�(g�?L�ð�?���Fo�08�&�7L"�����q�*���f?LQ�6�'D:f����xw	���8u{����&O�bM2�a�0���i3�*�q��ôAd�.�@/�Ǚ��{���0]�ä��,��~��oJ�������΅]�'���.�w��n1Aj�[۱z3)��o
9���ˈ��t�?Nnp�Ǘ�yü.na���I�+F�㹸q�IK�\�8���b�R6�G�k]�c~'}��Oq�A��=��OaHs��]�qZ��$݇Qpqu�_��]Λ�"�|vW��~,?v���2��6�09��vz�w�3��C�ŧ�֭5�3>�	�s�5�iʃs^�C�]��v��wY��x�4�����
���������S��3
����qaJ�t/Zͮ�a��m�.�Yf����t��bO;���t��ne`�N��>L���r��n1a���[�d���%���IQL	��&�Z��=�s�V	���3��?�>�.L���b��ă(�H"���Ps��6^I�ZE��*'�q�L����.��U��n���a�b�u��k��Z~�
����g,��ˆ=0K���=�"�L:{�)*'���I��'����øy�Ƭ����T���(��V|�N�E���j��XX�Mx��]��A4�}7�i?˰[[x@O+��.sI%"�=���Cj��Y��.�F�|�,��F5]M�.�f�Q�_�a���=���]>�
��<����b�x��pƽ8S����(*�Lw�J���˺\g7����	���D\>��i�|���t�ߩ�Q��9h;�.�r�f~��.�@�0�H�Q�J�S����eF�v�/�Il��v%����N����0����6Ue�r^��Z�o�=�*�ѭ'L��a��t���a�d {/��0	��N���%D��0��0i��p��:�a�لIp~Y�0킇y�U^�0����3L��0킯K���{�{��!�����{�$�7i�5?Vw��UL5�����&-���$�a2P�#m�e��>�&e�5�/ì
!�p�.D�kO���ϯc@N��N�񩥭1�;U�$L�����:�����G�;�5t1	�I�̨KJӭ�}-ŇqLFw����V&r�HRg!j,ä���5��w7SE��u�0���u��y����G+��c�wr�Xg�0����FY!����.�N�s1�ޏi���7�bK�a�1��?a�mD��+�Ѕ��(7�d�βb��DTa��h��~�:q�aܰ�EjV���~�"�`�ͮa\�N�~w���x�j������Fi��}��t-�bj���:�Ƶ�g�N�;�)�ޤq�;-���枦������a���.wa��)�t�����Yz���N+�坔��"ow��Ly�U�qW��Zc;��}�A�ay�yჸ�$	9�J��cn#3#嫥k�9T��@uo�Ù�¤3��%6t?�s�����$�Hm�%]n��I��B�1�������ȅ��s���1/�t>�0��_�w����*�7�a���_�?�7��3(WN'�|���;w���;'w��a�$e
����a��}��YC�<��ն=�@��d4'�
+����������?K��2ø%-�)� �0��˙.��Xa�=��na��R��m�W�{	�}/��Ř�:L�䙂��[�9�h�0ں�E�Z�*U"�gS�\=�/Z�}9��Q���\���p�w;mFo�>����F�ᶗvg�v��0�B���۵��P�0�P6+g��tc������(�l��
��'}J´CּE�eF��_�}������!�/+��-绘����a��:2·c!�iv�1���.������0HuZ��#�.�7u�~	�v[��I�7L�Bˑi��U�b�}�v�3Q�w��v���89������؞�K��/viM�ǚ�0i�3B����TL%9��&��\&n1n ��e�IY��*�u�F�u*�0�Oa</^���I����K�{���(��K;��_��Ƴ-u�ݖy����^Lr�a�e��݆q{|m+��b"���]&�g��<�A�XF�0�K��Y������'��ퟮ�a�z�q��0x�|�s"�3��H1���:���]��3V&��Iż�>;u�q���6WL��7$v�¸A6���"!�O%�fXe�hݖ�k���t[���y�\�#Ln�a�+�1�7L��4w��q�7W�X�;��Ǫ�A�n��4�rz���.����Obf�|����)�Ť�R۽I%}z�wŘ=��d�q���Uy搑��8�{+��s�5���K��0n;de��*,��F��gD��p���K�0�7L�0�&�ޗa<��=3èr�y�����8�1Zҁ�]����pF��K����q�N���B���K�n�g:YH���j�>^]�E2��7Ѻn3�d*�(�5m �.ٔ�.�0��L��T9]�IT�}:�I����u�ҿ-������ַ-���յ�)�K�a͕�Oa�c��]��]Bd�K��0J��Ք6��|��/9~/�
�� �/y|�4��q=oKA����i"������A#�����	���%��bYa�~�"Ym�������7L    �Ʃ�/[�vU�υ��M3Z5�3�7L���NJH�r��N�y�߹.�N������9�������M'-���~�+xf`����d,y��0�pä3.��aZ)a��]��V�v1'�i��I(;��0�'���t�-�(��{�����x(��� �s⡽�=�k���ô'���d|X1*$øjc/�(<��O�\�����#��|;c��na���t�a�]ʡ��C��3em��X�%Lg�a�͝�Ϣ�Y��ԛ�%�0	��ړ^��g��CK���9 L:�v����&�JK�q?ץ �L*&eE��������}�ۥ�w��מ�a�>�~*��N����
�u]�0]��8w?�U�}� �$�X=��Z��l.����Ea\�I&���\�0����8�b]��v�n�U[a2��qv����������i�Y�)����H{�xֆi��.��s)��|P5Kt͋�y�����Q�k���x8�r!��]K�Rg<Wdn	�0H;�S���0�'C5�n���P�Q\m�û]�v��ּ�(�.���Pa-��ogpwK�����H�:�N�Db_����'t�Z�8�z�n���r�a<���ԏ9���!)��]�[wm���}��k���vi'=a����F�S��ǚ�Ŭ���0X�/H_`W�<%kV���Λ|ԧƳ{�_+�{u�5Y��s�x]���qY���0.��T��eFз1��b����>�2�mY��X�Q���Ϣ�D�a2����}�db������yќL;R�K��\=���.�a�^����z*a\a�wr3�=�#sO�yY�a�>/��`�0J�����uj@�����%��%Ì���tn�0J.�v�Eu[v��׿QXv����j�s̩і3Yc����;�_-���h���T�%z���&	�(nn�CUL�/��꾘���>�Y����#�w�0�5}�[��ڒ��ȹ��%3�B�%)v�ŭ3��d�P� ���RTaT{�6w;�?L,
4�;�v!��h��Q�i��J�X�.Ϸ���9V�	�¤r�����r�<��g<��t��IlɄн�_´U���Y&�^��=F}��%]Z��߇]�Of�����;L{n���0��I!�/��3tg�ɧ?\�.m��O�Ԥ�j�q7K���I�i�d�~	��|_��cO���Y�3�=��sY�e^����1���J����Nϋ������qZ�օ���uɩ��[%L"�anK؆qh_�����ym������s��c(_�n��靶��������Qa���h��ϵE�Jn��e^r_��������/ŉ�u&�X1����̇)X�_�TG���%ᴆ�ٽ"��x�}1�gJ���I���4�5�����ԛu��b=��lܔ���}F�İK��ͽ_�{��z�ms���\�)��Y��>/�DD���r�a<���̈́�6�S*���>���%Qu��X>���$�a�y�Ӝc!�~I*�x�<A�.�����xDw{�n�ְ�s���ܭ/e��.c�4��$|Wc����J�]"!��K�v���c_t�	�V_'���v��y��+�p2���Nz݄�Z1\��'l[si8ebw��	�Rf��\r������^([D7�b�<�S���v��'�p(FQb:�am,z��FU�ŢFQ)A֚�<ׇyl�tZ�0� ��8a���M1�C�1Ba�o�*?�H�U�dt&��f�z��l���>I0��`�U�0m�˦�\{��(�Cx�.��r�3/�q�Y���g��p�����5��[/���W����a������x�ZN=�/�a�-��>�]�Q1
����$��:��e�M_�/؎��/J���S�i�����KV���l7�'J��=D֢���<g?7�$H��t�n��i'�ʚ�=��v�8ՓH�NW��i�iU�I�-F�4E;u�v�0��H��c�͈9�m��o��v2�m�:�z�N�����J������xXV`<�����G��A�U�9�����@��
�_�¤$�g|��:��c��H�h�e\���$�.�dU�����s!�L�_إ?���p��{��t�9��GK�x��W.�E.o�d���Hs�f�˼�㥏sZ�>||���?L��uD͸d�>���%�]�9$��Ɇ&L����׎��b�ߏ.#��D�%3.�q�J�I�YOt�z�s��0���e����9��W��f��Ea\}��u�0�tr�����܈)�Hw�<��θ`�J���O��u�NRŨ�|��抉ŘJ�0�'s��qF\�#�M?�,Aa<��+�ɱ,�2Is��0�����N�����^����R�7�R\w����F���ϸT�ݦ�0��8���¸w�ˉٝ�+�wi礔�]��%���)a\�����~�vҥu8/�H�#�΋�rF��
J���;�i�Յ�N6�np��k�wvJI�6푣~���d�6}�kf�h:�j���71�w��Ua<�����H��	`�2���� �q1#�K�_z��l:إ?f�a�,���.�I%츘���8.A�a2c����p,&5��K�Ph����8Y�{y^l~a�q���ǥ"n��*c9|�0_��\v��=��\�'���尺b�����e^Nx�Sx9�&�2��!+FYn�������_,i~#�la��m��0���CU7�Լu;���?��r;���5d|.�G��0�	����dɬ�˔X�W������}��iK�%T�0|���Ƹ�>|:u!m�y���0�:apC���R��ɍ"� �9Lf�y�z;/Q�a:J3<Zza������u�0��i{�I��v���az��:���.L��0魲S��Ӯv�F��K�e�v�t�v�y�Qv��_�I#t���l�a�.�M�M��a�[�IC3/y��t��K �a��-D��v�e�����j�|����}ޥ�mw�׵>�5ݖ�$��qwy]�b^
�I�1��w�2L��k����&]��%�'G1	mŨ\,Fa|~��?jI?5S��j.LT���a�@�X��Lzd���ȇ�O��i��{-dܟ��8W>'�����2��?GeJ�}�����an'��Đq�7gR�B���J&՗Ǡxa2��q&]����TF�q��!R��.�q���M� I����Y&�עf���-��f�C����T���J�cl[������j5�e�R;Y̐����p�ٝ�0��KE�y�zv�q;Lk6ik/��/�����Š�z�Ss����C8�F����y\��Q�J�s�e�,�Kj�y��&�K�t�ax�����:������3�ؠ�g8�s�<�<w���xh�4\�$��=VX}�d��9�]�'�p?i�O3�fF�q^$�isU�z}���s^�ץ�n�ʴk_��%q�$n��5��=�e	����e^�i��,��rj�&��ڹ���,��Z�:}���d,8L��.*��<^P�E�x	�������{�Hc1��
[��r=�b�2%6����ص%�޹mc�?�
W�
�}��ۉ	�%�$��PJڎ���5s��>�[�v��y�o;�E��_sF��N��b̻u�g���%�a~����1-a����	&f}]WuI&��<�m L���R�v�Z6^1��ź~�R�@p��9��ZI��~�%2L�s]Һ��$L�s]���o�]>L+%L[��u)�0�<���S�$b;z��!T��Z�Jx��9L"|1z��qē$��4��K��8a�a�=��$Vf��Y��|I<&U�a��HE&�z��0��v�3���%�י��s=L���E���8�>�2�id�,�d�^�'���됦0N��Zװ�'4����-�e���j�.6�0N��V��.����ڍ>�[�[���G�l���a�c�<�^'H������-!�D'�Ř&Y�0uf"7��Ɓ�1�ϱ.l1��n��1f=��s��0J���R�QΈ)���w��d]"7������/���z�9�rO���0�D͑=aRӬ���a\��~�a����+aR"���U��*�2����]T�t�?����������z��A=2 古Z���u	�,�(�\2ٮKPg���֥��J ]  \���;���v�v���K���])�2Ft^�d�^2���;�T_w�ô0�S����L����kx�gZ;KA�2\�:��z�f[�l�1<�gѸ����q��R�иH�8�ع�����֤�?H�c���܏�S ��R�p��#����ÅqM;�QΛ�t��0�3�<�b�0�Ip��c��tό���a�q�T*ϋx�>�_J;�	�'��%�mE�����/�]���.��0.�Ĭjȗ�bk4w����b�㶹l�
��o%���JSS�3ir��4c�^o�ˁKa�*,��Z�Y��Ʈ�,���P�w~�D�����6�hP9��vy���}���E����vz����1��Z��n�a�9����R�tm+��/Ӳ�ԗ$�r޿���d��wG�1S�i���tF�i�ؿ����)Lk�t&�'�ҝ�U�(�_������}	M=�cDo�������_kvv�A�d*؉
���ٗ �0v�%�4����r_��a��w��vV����NL�2a:���)>Y��.cD?�0ias�Q����~,݇ݞ�J2LBF���E���@&���o����\�Y�c�So�vz�/&�U���})D��孕�o`��0����u�1�+L�})`�/v�})nz����Ml��)G�09��}v'q+�.Q���ώ�a���Ze���d�/�X��4
�v�*�|����(R����Ng�4#>[�ø�NB�E��c2�0]|vS|�NMM"�A�F�i�G��0n�a��Ta�Sؗ��t�坴�]���<T��}a��3}g�xCi����%�3�BR�lHݾ����?/�=���g��no�}1Q�WH7��2��N��q3�Ρu�6�^���Y���n��0y|�]�z�(��,&�/yn�`��B,�&G�06s�Js聯P�0Y��p��0N��:;!���|^��61.K%&���]��H��7c�n/�&�*�j�0)I�7Ђt����5?���b<r��2n�u�S��XZo̯|(�ϋl��S������sܪ���w~�}Nbۗ��0�.���a<�/y��x�a	�y0���twإ��fc�u[X�k_J���v�vn�;���K�k��gaJ��S��[��-���7���r��0��r1�b,�Q��/t0
��h'.�m�)�\nd_
��Q�[�;�r�e�|_���.�X�� X�g6_,�Z���Xq��z���s_.����0�)����V.l�Yv���KPrf;�ܘ���2���xU�նW�!=���Q��'�oS��}fЃ18n��]�N�I���U�i�]����/�����+�0�9�-t��M؆��0��ð�[�����������      �     x�}��q��е�����������ѥ��ۊQU� �D��O����?��g�����U�]�����υ��������3��~�Ͽ�>0Z��g���?��}��W.?�~����h���O�/|�����u��v�^���ṟ���g�-�S:��P����E�P�����S/p�7���-h�mmr$ʷd���c�H��Bb���<����{�`��.�?~rl�E|>��x|W��%�2J����\rA�rC������ӫ�������N>y�`^%�/��.?��1V򙒱��~��R���L=���Mv@���7��+�̒(g�&�`g._� ��ߛ䊴�<�p���X'��^W'����ً���^�j	n��������៰$c���'T=S�A�>���u����Â���O�G�pe����#���X�_ؿxPK׉X!!�t���
�+�K�?d��~�!t�)F�'l��!6����u�g�Oi� ���AD��Pa",��󊿡��A��K;����aMɐ�?��-%��N:�$l�D��6�b��������E�0v�E���8���(�͛�q�r��L�!�!b��$N��I�;4��ݔ�#���b��$�k�F���$tklC��a�%Ga���t�H���g�K��t�N�%'y�����ΒI�-�p6#���g�$��:�PR"v8�g+�8���/��Qvq&�i���|`?�Xǂ��$T�����$~���&�.A���.Υ8�yֹ�X���J����y�/Σ�x&�5�&�"��<e�m;��V��LB�A�&��xz�`b��c��K.'��|�$]D��:ɼ�|pR:��I=��y��I��T�u�<�)�_�&O1d�P�)��C��/��CL/·&Y�sڱ�)�f~q���*yI�����II�Q�q>H)����6��sDОq]nT�:C
�s���t��\�.л�0������5My��]J3�����H}7y��2�ݢ!�V�y��@�f�r�hs��=�������q?p�!�{X�=��O]W�/-��]�+<u�S�)]_��{�qݫ�뚥��.�Y!���[������E���O8�>;�Y�u�S7��o�U�]�-qNA9�"Tѽ�f�P�u�~2�o2t޴�v�d�/q�M�R7���T
~]ݾ%<u�+o�M͢�y�#sK	�-��׸򒥼-,u+o[!��¸�6°�6��K��6���a�Ө�qG-~w�C�Z��2�*�J4	-�<-u��S�����߿%���ϐ�}�R�Ra�}O��mt�Vy�}�P�S���<{��z�*�V�x�{�#`���;�e���I���0�P���;t�x�]�დ��W�ܻ�8�U5�����Ż6��p���{b��+�m��7<*�#;�C�{�y�|!���}�l�|������
ʲ^�,�fIuH��/���R�T���_:d�e�d�,k�/E[?�J�R���)�c��i�g��}`'[l�,y�b�`��5������XV˚����>Đ�ʱ�/A	1�u�w����M�o�j�!����0��o���a��&�Xʱ�E�X���w,�C�"I���0�B������2�جrƦ6尉�b����}l��8L��(��C�����&��qhqX�	��8�6Q�d\rq�⪽:<VW�\p�&.QTL�cD��Ou�x����^<a��|M<��'OTux��E�%�ʰ"4#ĿDX
��"���4J�p"-��H� ���B��CMF
EE
>D1�R�Ŕ;HMF�g.J��(a�(G��Y͢���={�"���sG���V�T4��Z*Z�E�Z��X2�m��bX��P��(��a����:��!GQs1��E��ř<r��$�\��m��8��X�˭��[�fn�$5���A�U��-�[#IM��dM�a���G0*��p���S��&��0�39�.ʼ,ꥇ��
V'�d^�0y�`�gr�*r&Gr��d>��t�;9��O�!Ki@��<L>&Z�jwr('C�:C	gCF�-ã�̴2��n����T'��j�ˤa�Bg���Jz��R��)�6��P���;�U�,a�,{�G��,	R��T��$8؝MѶ��$���$�L��ljĈ�J�P�\'�rr�t��J�Q�"9❣v�'���Ep]���$�"�,�Z��$�ZCq,�'ks��X鮭Ƈ�w�w�6y�b��6ʀ��<Y�)gy0��/�8�RE��/{:B�u�����Ǽ늙�K澮���b�몞U�<m]M�	�zL8�Y���c9��&�qڽ�(��z�+��;�*�f)+�C/����Dh�X�eg*-�Tm��@Y.yW��[l�,b�J�ŚwRǼ�T�)��TYEu(�sE��LRV��S�)^T&S�"F���j_��b!��UEQֈ��k]���$J��,�&56����S�Y�^��;����X��%r��vջ���^4�&��M��	+�W����-,�[9Fo�RM��Q%�w�j5;(��*�#�h"�>�*n׼��"��w���k$��B���T�j"ʾ���Kї7��:��}��X���̻�)����G �,{���x�b�,e��lN{wX�:�Y�޳�;�$e�X��w'�����k;�tv�Ǻ�#�mu*��:���.��RB�n�lֽ��lu1��>���˒(��f�h�5���)	��t���f��0�V)��7��N��-�M��ǆ�A�B���a�t�G���>�Y*�/�_F9Ɣ��s�R�=��r��Y�ֳ�b�(�C޳}-�>/�B�q#�l�޳�[���1Q9&*�(˘C�v�b����)����s:�2��yϵF\�sƵ�q�{.�԰�=W=���+��Q�S̘'����Q!�@����d�<�Fha���rB��Ǜ�4帛r�r O9��|R�a�{�(')ֽ�u��X�x�{R�֤��)�BQ
n���I���WQNY���p.g8�=�F��]��⤦Y��R����i"���A�l��a�1C1�#d=c��h�M�<������޵�	����?��?6B�      �      x���ˑ$��m�q\*��nq|����O��֚��-5�%e?���p���������_����W�����o���QF�����UV��D����J�ej���H42�L_��7C|mg:�n��{����-S�4��D3ӗi������d����^㗩e�;���L�Q���ie�'��t#�_��w��~�42Ϳ���ezǿt�-v�n����O��7kb]��X-��'���_KU�;b7�z��p��ĺ������'��^.�"�#v������}w���kN�Ol��\R)�G�b��{���y���X��'����N�����;�&��^.���)��-��������ϰ���R�~�p�i�.�m��SAl�+��%c3�`��i���p0��
�#=��+����K(��Dpn�������T��� v0]vN÷�T���
n�c�J���-�`3|/1���6Ƃ�����m��߈�����|[����#v�a��u��_B��mo�,x���,����v˂�pN0-�3\�/����6͂W�m��6΂��%��Ypn0��^���l3u��m���4��f�){�h�mx�ߌ����l��|�i�i����w����7��3×P�&�����4����e�J����ԂW���g*���_Bi+�ߞZp�鲟�K(ա�������?�f����q鼉�q~`��2�_����	^0��3l���%�
c{��P�}���_B��oO-x�C�u���_B���b+8?��m×P����A����
60���3|	�mV�~��p�iA��
�=���Sv�a��U������=���[�0�=�`3�+־��������|{j��b�{{�oO�b�{{j���×P,ooO-�_B��=��|{j��P��k7�/�XMޞZp�i���ތ���W�ڍ���`��0|	�j2ޞZpn��]���l��o�"5ޞZp�鲟��۩Ԍ��<�W���wz�~�=�`7�L�_B�0���<�W���w*������0|	�-�����=��K(���Ԃ��%���x{j�i�ʟ�Y���^0�η�|	�J��Ԃ�p�鞟�2܆/�X��^2��
60�������;������2܆��ď8��Q���l����b����K(��c-�7�V޿.��P,o/u�f�_B����M�3\�/�X�ޞZ�
�=�`ÂޞZpN×P���2܆��%?��ԂͰ��~���Ԃ�����ӃoO-���yߞZ����9������ӂ��6<�/�T5��S60\���_B�0η��_B��ͷ�|	��.��Sg|{�j�|{j�n�J�m�=��g�J����Ԃ��
�=�M;���3��Ҧp����%�?O����K��oO-��c�OHg�S�+M�Z�|�<V9>--zMy�U���U�iQ���ON��U�#NޤݪG���U�ƎhS��d�:�I�.���U,�����4]���戒U,�4�dK{uQ������V=��4����hS�����L�ꧺT9�+O�+�Q_E_V� ����P��_iZ�Rݪd���ǿ�����6U�Jۻ�թ���Ҵ��zT�*պ��6�^��G�E��JV�N~|�X���+_S>�+�T�*mm�1T�ꧺJӪ�*Y����g.�ΟjS��aU|pP������o�Ku����kʧ�D9�D�o�����?ե�K�+:�״N:��Q�u��U��,M��T�*Y���Ǿ]���+�om�d�)��E�*Y��ξ]��b�e�.zMٷ�3)�vѮ:TgiZէ�T�*Y�ZǾ=+�v�V�˾]t����a��}��*MWުG��.����b�.�U��,M��T�*g�.zT�)��xTh�o%�T'�v�Y�����U�u�}��Q%���^<�E�j/��i#:U?U�J;�E�=�d�jݢ*�6ծJVi�ط�~���Ku��U���ʾ]���Ұ*���/����b�.�Jӕ��Q}�u�˾]����p_���d�(�vѥ�K�}�*Y�˾]��v�QVž]�S%�X�ط�U��Ռ}�hS%���\��E��W^�vѭJV���o�ʾ]�����o�|�K�H��EWi��V=�ה}{<E�ط���t�JV��o]�[��b�`�u�om�d������E��W��9o���[���U�B$����4\�}��P%���o���d�*�f�.zT�*��6�v�V�̾]t��U���}��Rݪ�4�ꚲo}Y�CS�}��(MW�����*����E�6�T�6���E[iX3�Aѡ:U�*~�ѭJV�N�#�ʓ9���<E�*Y�JH]�TWi��V%��5q��f�gH���Ұ*���d�����D��V=�iUה}�(Y��Ͼ]��b�e�.���U-՗S<ֵٷ���pe���M���=���7f�T��.M�:�ה}{<��ٷ�v�Q��;U�*�X���[����_�a�.�T�*Y��|ط�~���Ku��U���}{V��;hS��C����z�o]�d���}�(Y�*zط�6ծ��:�����/�x��oݪ�4����om�|�j���}�(Y�Zwط�.�]��|T�)��x��o����Cu��U�f��E�*�����4��}�(Y�/�C��b�`�.�T�*V����4��}�hS��|�q�H��E?ե���z��Y�������vѮJV�����T��.M�:�ה}�(Y�zE����S��bU�ވ�U��r~vE�*���om�]u��4�[ų~�Ku��qUG��������aU��U��T}��xJ��5�[���U��\�j\���J����s�S�S%������Q��|�x<%t���(��9��N�N�O��R��|�O��^S>��K�����D��P%�Tc/�']�[���(>���ό���y�CW�S�����E��[�eG�\~O���H�3D���v�Q���3E�*��.�9ݪG��b��7K�M���U�9�NC�S]��[���U�W�,�JÕy�Ut��U���:ѥ�UOiZ�5�=$Q��U�tա:U_V�|ʥ�ݪG���4�AE�jWe�K�f�7�_i��RݪG������<�V���[wc�C~l݌?g"�U~�ߍOq|�W��	�Z���A��y�{Τ������[����qs�Τ�H������˙�K2B�83uIfl���sw�酱�7���3��i]l2�<���ߘ�ℋ{|���9�⸴�Lj�"��f�oܜ{qZ�}��Lj�i���xǋ�̦ߘ��Âm��p�Τ��%l��I-�{6�Ƥ�K.���ܝGq����s^�/�<��G`|�iⱔ�͹;�Z<|��s^��m��Lj�����tq���<�I-�T��|�oqXZ}��qs&�X��[����W｜��q&�Xrk��qs&�X��o���W｜��q&��}�g��0��r�τQ�Q/>�?��̬�X���6*|���_ �LP���ƣ8^|:��g�3u����-N���jܜI-�ץ�O��yǥmgR�O�:-'̿�xĨ��1��Lj�����yǥgR������9�Z����ә�rɥ70��Ǚ�r��70~���(��p��/�x���f�_j�M���/�8F��M��sw�ii�Ɵ3���@o`Lj���@����9�Z|��>ke<�?�U�b�70>�׸��c8���(w��<���>gR����(�Z�L�nߘ� �i�^�;�Z<��그��y�{�Lo`��cɭ_��Y��9�Zܧ��i���U�7�G�Z�1oܝ��,N��/gR��TޑT����Q��1��<�I->j�-	�弋㽏3��'Q���͹;�Z~�Τ�î��1��rOo �.3�Ujl#���p���������z���x�̓��9�Z.������{/��Lj����iLj�*�,��<���70^�ۙ�rU�7�70n������y:�Z.��ƻ8^�8_c������W�^/>�I-l�*��x��|��2�A<.֘���.gc5�*O�Z<՘򪼝��K-ΞjL{Unν8���OgR�%�ɯʻ8^�8_ez�x��1V�ǋ��Lj��2Vy;�[��Fo`ܜ�3�ł�tX��y9�Z���Ƥ�k*��q+N�7    0Τ��&���r���o�#q�ٱƯ7�`[c~�rw��o��m�9���y;�⸴���͙���b�Y/�9/��Lj�Y����97�^��v�3��G�����v>�qiW��Z~���ܝ��,�K���3���=�טi�#�ḳU�Σ8�0��*Τ�c̦U>���W��Z|�0�V�ǋ���9�����ƼZ�Z<�ؘYk�z�V�V�z��<�_j�lcc���v&�X��ck<~�͹����Lj�`3�Vyǋo��|�'�Ś�|[��Lj����*�Z.�s9o��|��Ҿ�ss&�\���<���x�弝��K-�~l�Unν8ݛ��x:�/�8v�1W�8_ez�x<�1W�;�Y�b�70&�\4����U�7�'<���ܝGq��t&��Ӥ70������*��Z.����y:�qi˙��>����3$W��b�fL��p���ޟ�r~����U���ƭ8-���x8����Rf�*/��|��Ү2��qs&��	fv��,���I-�T��*��x�Lo`ܜI-���]eR���9���yǕgR�%�a�ʭ8]�����rѤ70��I-�5z���R�S�cu�_j��"�u���t����70��Ǚ��N���͹;�Z�k�Ƥ�+���v>�)5zaz�|ڐY���y�{OgR˅���xǋ�Lo`Lj�����Lj���o��Ljy�Io`ܜ��(NK�70��_jq,Zc
��q�����#�x���p~��s�L�U^λ8��8_ez�|������y8�Z|0�Wyǋo��|���AH��*w�Q�=�I->,ѫLj�a��^�Lo`܊������t&���fX��v>Τ/��^��ܝGqZ���缜_jq�[cp��U�70~��C��U���+N��o��Ljq��_eR����x8��rz��Lj���_ez�| �y�ʽ8������rM�70^���ǥ]ezcR��wF�*���ǥ-��Lj�"������U���y�Fo`����K-�.e֯0�~�[q�7�~�_j�|(�?�Z>���_eR�%�����ƭ8�Bo`Lj��2�W�s^�����8_ez�|ʒ	�ʤK.3����缊���Ǚ�b�e�rs������ә�bEf ��v>η8-����9wgR����ʟ�r~�峩V������������2!Xyǋ�˙��Ӏ���*���4z��<�I-?�����)�������)3���3��g	���W/���3��Mo Lo`܊ӽ���3��Lo`��wq��q���� (s��{q��p~����V^�/�| �q��ט��ʭ8�nF
+gR�5�����y;�⸴�Lo�Ϧ2[X����������s&�X�0�|�oqJ����9�Z�a3gXy:Τ+2�����-N��70n�ݙ�bMe��缜I-�T�+߿�χ2xX���|ʒ����o擎V��Wqzݯ7P>Τ�+��sn��y��}��s^Τ�k�w�I-�s�0b�V�.���p�Τ�K�ZΤ�s%V����܊���y8�Z�2�Xy9o�S�v�������2�Xy8��x�����O2�X��%6&�ݵrs�����<�?gR�5�n��Ljq���b��܋�cn��t&��et��v>���W���I->,`�<��ŧ�缜I->,c�|��Ϲ����Lj�Q�0c��y9�⸴�|������O:2�XyǋO������[L6V>�W�� 'd��2�Ś�|c�Y/�9�Z.������{��Z.{�Ƥ�K����Lj����Lo�'B2�X�;�Y�b�70&���e��)����������1�Xy:�/�|0�	������g:2Y�9��tozcR�e���x9o�S�v���@�!+w��<���>�弝I-o��"w�"�x^�3Y�;��_yg.���Lj�`w�"+��x�Lo`ܜI-���\d�Y/�9/gRKO��\d�Lo`܊����_j�eg.��W/��_j�eg.��K-F��EVn�/�xV�3Yy:�)z��|�I-U��\d��ܝGqZ���缜I-�sz�Lo�hv�"+wgR�z�8^|9�Z~�_ez�V��Fo`<�I-?,��Wq��v>Τ�6��qs��/�xʲ3Y�s^�����8_ez�xʲ3Y�ǋ��Lj����EV��Ǚ�����9��tozcR��zcR�����8_c�"�xұ3Y��X���<�?gR����ʧ8^�*�7gR����ʳ8^�s^�ۙ�bEf.�1�A<�ؙ��ܝ��,�K����v~��S�������dg.�rwΤ�"+��x��|�I-�s�"+7�^��Mo`Lj��3Yy9o�S�v���I-?K��Gq��t��I-?���I-?,�����s/N/���x:�Z~��o��|������sw&��$�70��_j�fg.��K-���E6�70n�i����y:��v.��Ƥ�+2���-N�70nΤ��"���t��I-�=zcR�e�� s�70n����EV�ә�b�c.��v&�Xט�lLo�*v�"+wgR�o�3Y�+�_����O:v�"�ģ�����/�x��3Yy:����y;�Z�B3٘����b�d.��p�����Z��2Y�8_ez�xV�3Y�;�Z���EV��I-Wdz��|�����\deR�%���x:�Z���ƻ8^�8_ez�x��3Y�;�Y��9/���R��$;s����I��\d�^��Fo`<�?�Z<�ؙ��Lj�h���Z�����y:�qi˙�re�70������͙�rm�70&��Lo`���xn�3�R�8_cF.~q�bg2�rw���'�:�����.��>Τ��ܜ��(NKk��s&��d���q&�X<£ܜ��(N��OgR��5�(o��Lj��1�B�9w�Q��6�3����	�I-��|�'��m_f�ܝ_j��^�Kݕ?���R�g�:��|��{��rs~��#}�o7V�����r�Τw\�E6^��+�jν8^|8O�ϙ�reZۙ�ruXWy��I-�ݝI-���2=�8^|9o��Lj����ss��/�x8��P�/�8�3Yy;�[�^�����K-N�|�2��=���I-z�S�v��.��Lj��|q��t��Wq\�v>�W�� �뜷W��Ù�⯨9"����ŷ�q����X]�d�rw&��s�R�s^�/�8
�sP�*��qt�cm��y8���Jo`���3�Œ��cz��Lj�`sBy:�Z��|j^yǕ�Lo���ac��<�I-v�|.Vy9�����3��Fo`ܜI-����t&�\���_j����Q���q�\��+�/�|̊O�(O��yǥmgR�Ձ�@�� ����ʽ8-������0���r�Χ8.�*���H��H�;gR�?��Ƥ�w=�Ƥ���2������ֺ�K-��-f���R��jx?Sy;���®2���K-��,��<�I-���;5�ۙ�b��-	cz��܋�����3���D����Oq��U�70nΤ�Lla���W｜��q&���)Qn�����Ù��~�g�2��Mo`|��2�A>0D�S�������o\y9��x���R�'��?��sw~��3=�EV����.N���Z��2Y�9w�Q��Fo`�9�Z~��gR��zcR������rѤ70����70&���e.��-N�70&�\��_j�|	s���⸴弝_j�t
s�������%�EV��Ù�beb.��r�Χ8.�*�7gR�u������s&��g.��)�/�*��Z,{�EV�����s^Τ���EV���q�Yg.�rw&�Xr����Ǖ/��Lj�"3٘���9��4z���R˧r�������-NK�70~��C;�EV�/�8ū3Y��r٣70>η8ݛ����rM�70&�\z��?��Ljq+�\d�Lo`܊������t&�\4���3��Go Lo`ܜI-W&z���9�����"+�[��Mo`ܜ��K-�Na.���LjyKo`|��ů1s��|������y8�Z���EV^Τ���EV���ƭ8�nz��<�I-�\�"+��x��|���I-���\d��<�I-n�������3��}*s���s/N����x��|X���ʫ8^|;����1���ʭ8�����o�C�EV���    ŗ�v&���e.���snν8-�Τ�9`.��r&�\4��Lj�h��s+N_�y8OgR˥g-�]/~����9�Z�k�;���ǥ-��|�_j��s��[q������K-�eb.��r�Χ8.�*_R�E�6gR�e�gR����9/�]W~��1s�W>n�\d��<�I-�T�"+��x��|��r#��� s���3�Ţ�\d��y9�Z,��EV������ܜ��K-�b.��W/����K-��b.�����s/NK�y:ΤK.s��I-�\�"��c����ݙ�b�f.��缊㽷�q�����s����(���Ο�r&�\����2��1�ŷ%���<�I-����wq��q&�\����sw~���e���ʟ�K-�b.��q������/�8��3Yy8�Z����˙�re�70���Ƥ����1��}*����Ljy�Ho`|��ʯ1s��I-�"+���ǥ-��|�I-��"+7�Z���\d���R˃������Oq��U�70nΤ7��EV��_q��r�Τ7��E6�70n������y:�Z�2Yy;��x�Lo`Lj�"3Yy8��x�ϙ�b�g.��q������͙�r=�70�Ο�*�K�Τ��`.�1�A>��\d��<�_j��s��Wq��v>�W�� d.�r/����s&���f.��q���yLs��I-?K��gq������r��70>η8ݛ���9�Z.��Ƥ�+2���r�Χ8.�
�"�x0n0Y�;gRKeo0Y��O��"+��x�LoϏ�"+w���R���s��Wq|aۙ�R��E6�70n����Ƥ���`.��W/���3���6��lLo`ܜ{qZ���t&��G�EV�Χ8��*��ss���ʽ8^|8�Z���"+��x��|�_j�`�`.�rs�Σ8-����s~���e���ʧ8^�*�7gR�U���xǋΤ��"���q&�\���I-Wz�Q�^7���缜I-�z�Lo�6�"+w��Lj�p�/��Lj�=�E6�7�'�s��_j��`.��,�����v~��#^�����EVn����EVΤ6s���3�Ś�\d�Lo`܊��70�ә��>���ʤ7��EV&�X����ܜ�3�Ś�\d��y��Mo`|��2�A<^6���ܝ�3�Œ�\d�弝Oq\�U�7�g�s����p��qi��K-}�EV>η8ݛ�����.����Ù�rM�70^�����8�Z�3Y�9w�Q��Fo`Ljq�\deR�%�������7gR����x:Ϋ8.m;�LoϮ�"+w��<���>��Lj�i@o`|�v<�6���ܜ�ߎ��s����缊�Ҷ�q����v< 6���Lj��1Yyǋ�˙�b�c.��Un?gR�E���ʣ8��6�?��Lj�*2Y�����ss�Τ�s����x��Lj�p1Y�����ss��/�x�m0Y�s^λ8.�8�����\d��ܝI-��9�?gR˵en��|��_qZ�ל�3���M�8^|9ogR�u����W�.��3��ڲ�3��ڲ>�Z<�5���|�oqZ����sw~��SX����/��k�EV��qiǙ�b�\d��ܝGqZڙΟ3�����Χ8^�*�7gR�E���x:����y;�Z.{�����Lj�*2YyǋO�ϙ��n�������{��Zܐ1Yy8O�Z��5�������-NK�70n����i�"+Τ��EV>�W�� N��EV���y�X���3�ŧs��oq�8��qs�Τ�=s��?�U｝��U�7��s����p&��,�70^��m��|��⹹�\d��<�gq\�缜�3��ƃ�����P�`.�rw~��Cy���ʟ�K-��EV>�W�� ��EV~��Sw���ʳ8^�s^�ۙ��Ӏ�@�� ���EV�Τ��9���缜wq\�q���EV&�Xϙ��<��ŧ��Lj�a�\d�S/~���I-�s�"+���ǥ-��|�I->���܊����_j���`.����R���s��_jqZ�`.�1���K-�>�EV���+�K[���8�Z,��EV&�Xr���<���W����3��Io Lo`Lj����Y��9�Z�L��Ǚ�r�70n������y:���;�"+o�S�}�����Km�Ko`<�I-�\z��|�I-�\z��܋ӽ��I-n��������)�K����͙�r=�70�Ο3��6���q&�X����ܜ��(�3Y�s^Τ���EV�����s���3��r�\d�Z>��\d���R���s����[q�7���p�Τ߻g.��v>η8-������Ӏ����y:�qi�y;gR���"+7��Lj��3Y�s^��u��Z|0٘� ��d.�rw&����70��Wq��v>Τ����͹;��4zcR�z�Z>�ȤY�Lo�#23U���O2�Sy:����y;�Z������͙�r]�70��_qz���ۙ�rѤ7�70nν8-�����rɥ70^λ8��8_c�)�Z���QΤ�"�h�Wq\�v&��^�I����s/NK�70�Ο�K-�d��q����&ߔ�ܝ_j�&_��ǋ/��|�I->K��m��Lj�a�N+O�ϙ�Ⳅ�NV>��]ez�|ʒ��U��Ù�b=�U�Wq|a��8�Z���ƭ8]���x8�Z.��ƫ8^|;�Z.��¯78q��;�{qZ�������Nf7�..��|���8-m7gR��c���9�⸴�|�I-ז�sn���;gR˅�|��y�{gR˅����s/N��Ù�r鹟3��������s<����EV���yǥ}������N�*_�Fj�}�1*w�Q�^X�Ο3�Œ˙9��|�;�Œ��0��<�㽧�缜I-lN�(_�Aj��rJB�;�Y�^����3�Ŋ���I-����rs��i�s8�Z�J�N���R�@�ğ�U~��r+N����/�8)o�	0��y9�Z���q&����/�͹�{�O�ϙ�r]�70>�W�� ��䗼�ݙ�r�70&�\z��wq��q���Ƥ�+���p�Τ����.�?�W�� �U�;��<�_jq���=&���R�gy;D��2�ź�\d��<�C�t���y;�Z,\tS��Ƥ[w��<��⸴弝�3�ŝ&���Lj�*�T�Τ��<G�wq��q���Ƥ�"?��/�7��W����K-���5+_ez�|(R��Ù�rM�70^���ۙ�rɥ7�70nν8-���x:�Z|k���ʻ8^�8�Z.���͹;��4z�ϙ�rɥ70>�W�� 'd.�rwΤ�����y;�Z~����Z܀3Yy8O�8�nz��|�_j�� s���s/N��70�Ο�K-� �EV>η8ܛ���͙��c������s^�qi��8�Z|
2Y�9�Z|1Yy:Τ�D�EV>���W�����"+w��<���>�弝I-���\dcz�V��Mo`<��3�Ŷ������8�Z|P1Y�9��toz���R˳�����Oq��U�70~�幊�EVγ8��s&�\r����U�7�G8���ܝI-6=�EV����.�K;Τ��%��͹;��4zcR�������r��70���Ƥ[�"+gR�E���x9o�S�2�7�70~�塍�EV���+�K[���8�����\d�V����EVΤ���d.��r&�T�'s���2��q+NK�70�ә�Rќ�EV�Χ8��*�7gRK���\deRK5u2Yy9����Lji<���ܜ�3���<����9/�]�v��2�AV9���ܝ��,�K����v~��#�������͙���2Yy:Τ��"��1��]�d.�1��1��Jo`Lj����˙�r٣70���ƭ8�Jo`Lji�;����9/gR�e����*��#}�����y�P��?���R�'s���2�A<�7���ܝ�3���Eo`��wq��q���EV&��	f.��p��_q\�r��Ǚ��*����͹�{��Z|�0Yy9o�S�v���I->����<��ŧ3��s����q��ii��͹;�Z|�1Y�s^���ۙ��C���������󡓹�ʣ8��������_���8�ⴴ�(7gR��1�"+O��yǥm��Lj�a�~Τ�� �  �;�Z��k:Τ�k��Χ8�Τ������y:�Z�k{9����K-���EV~��s������y:�qi�y;gR������s/N���y:�Z��弝��-K{�Lj�p1YyǋO��y9�Z���EV����܊��Zw&�X�����ǋ/gR�E����W���ӽ{s&�XS���<�?gR�;M�"+��z�χN�"+w�Q�^���_jq��d.��.�?�/�8�t2Y�9��toz���9�Z����Ǚ�r��70n�����Ù�rM�70^λ8��8�Z.��Ƥ��"���p�Τ���EV�Τ���0��qs~��)�������+N�������lN�"�������\d�Q/>�I-nD�����I-zazcR�?��Ƥ�7d��_q��r��Ǚ�b�`.�r+g.��p&�Xz�������)�K�����d.�rw�/�x�s2Yy9���	��\d�Lo`܊��70Τ�"s��Wq��v&���b.�1�A<'9���ܝI-n�����9/�]�v��2��1�Ţ�\d��<�I-�\zcR�u�������7��Ljq��\d��y9�⸴��R�G�&s���s/N��70�Ο�K-��EV>Τw{�EVn��y��Mo`Ljq;�\d��|�I-���7�^�^7��1���Bo`��wq��q����x�d.��K-���EV��/�x~l2Yy;��x�k�\��M�"+w��Lj�盹�ʫ8���|�I-�ט��ܜ{q�7��1��s��I-V&�"+�⸴�Lo`ܜI-�=�"+O�8�{9�Z,{�EV�����d.�rw�/�x�j2Yy9��*���U�70~��cV�EV�ә�rU�70�Χ8��Lo`Lj�"����ǥ-��|�I-�szcR����x���Τ��=���)�����͙�rE�70�Τ�+2���v&�\r�����s/N����x:���),�"+o�S�}��N�����y�{O�ϙ�r��70>η8ܛ���͹;�Z,��EV��I-Vd�"+�Z���E6�70nν8�Fo`<�I-�s�"+o��|�����I-nߙ��<��ŧ3��z�\d��|�㽯2�A>��\d��<�gq\���R˧Ϙ���R��˘�lLo��1Y�;���!-�"+�˙�rU�70���ƭ8-���x8�Z.���˙�rE�70���ƭ8�nzcR�%�����rѤ70&�\���I-�z�V�.No`<�߿�_>P�`d����?���q}םM�z3�������d�^B      �   g   x�3�t�K��,�P@�Ff�F���
�VFV��\F��%�9��y��sz%$��Tj�雘��X��GP�)�[Qj^2�S�+5�tO-�Es*v�1z\\\ ��2�      �   �  x�m[ݱ&�|>�I�. ��r���F��/.���A�_�Q�O���~��#���C��?������t���C�OU@7��+2��o���S�/`�,0,���q��&�u��[���3ܑ� Zm���HM-�0ϑZ��3��VzZ{��K�#�U<�ʯ~�O�P��P��`��z�龥Z��Y�G�Ԃ~�}���ۛ9��O�Z�S�3�h���8�S�~�诅)맄�V �S���Q���3����5i��	�v\���f���Z�)�!wK� Z�()������<�qK���wڽ�@?��~���T_�j�%Ƒ�w�	��@V%X�~p�G� j���ں:����т���ގ�q $������G��iƑ��)��ޒ� 1�~z
�`)�9��cA�(&��F�C�q��E�oF?�_�9t��� �ni"���ݪ��n	9����]��,J᭡�u��#��Ԃ���|P@u��	?�衶��'꒫�m �oI�$| 9�b՘�T�V�w7 �^8R]�4���`� Dz��#w�e B�_fvՠ�o��c���B>�;�P*4s�B��j<���Z��k�oi�F�rE@���"�?h!s�%f��6� �@z�;�zz��"�a�X�l ��?�C��� r $㣱k��ei�AV��̞.�|��z�����zM-��Ao�(�I ���·Q_�h� ��wd 2��Td�:��#���E[�%��\�џ�_��"(�ef��:�4���H�ы� x�o?Ėe~P�)9 -��)��r��7��%���n.z�7`�r��|��@�O[���3��t[�j �F�\*�Ԝx�z\����4}!�v ԕ$S�%��r_+�� u\��
�����1<m=NV�i��T�uQfXx��	��<��ZXR@�q#��@u���66Ӝ���L�%c3�X��J1 �T���|��@R�����zO8��V� �k Z��V_Ȥ��ʧ���`I?�F}$6�)���)*����A�����-����i���$�h�E`�7Ͻe� i$��t2ml������.3��j� =����]��� Fb�봬vI��@���K�5\C��i��%6�h��pG�/ E��#����܎�� 
�#��~�|,���~�%6*}G���ƻ��|�5��-�0> �!��z\cN��:}�]� �#I�!|���W}m��|iܥr���E{$���{�9��@�Jԡ"4�[� &�䉝��ps�5��Hc!Z�Բ��Q��}���{���l��3К@����?`@�H�p�E �DK�e�Ky3��ݏ�\�X����C�p��<m��P��A�C������$�KQ�F�k�" ����s��u�V(j�Bw	 �advo�q�F�l�]b�V*g�0��~L���[����*3�����������B�G�p՛1Zm Ĭ�̮�|� hD�/'�04�`��Բ T������i���i )��NQT�r�i�v���)�^Tchdb]Z%�km�g42�[_�9m��΢w���
 �Tc�2 �����6 L�#�4E�Y����#��R�E1�5W��l͸I�������̎�*�Pl(ժ���~,hC�ge��� ����R����P�h~k�$i�#sG��r��7X,��[���u�|ɴJ$�K���*���}���L��`x��r�9.����U��.ro�)�㠑m@��?L�㪿%hd�=�=��#��{R,Q#�9N}W`��㕦�-S8?@#3 Qb����X8<m՛�Hc�Vor�i ԥ�ݿ��	��MC93cc��j@#�]�g��¢@=�Ѳlp��T���9tg4�轥ڪ��U242�I� Q8��>���ɖO9kdKP���Ff�jXEm	D�TB#� ��H��j�c��L�?4-3F+(�� �m�֥���Rl���6`Q�C1v��i�����P�V��chd�f̸͗����l�ԝ��� ��o���<;��>� �f�!�`A#3@+�gSk�wNC#�#5�ҙ:�*�X%4�im�q�e�
��̴���@��Mk���>,�g��D�� �o8�Yh=2c�4���.d���n�3�P��Shd���H�nuG⿀�;-����6 ;���m��� �|I�-�ANܵ��{�Ԇ�v��;a���Mۼ���DN��ӻ�A#3D#~�X�=�14�m��b������m%�7ؤ��J���@胜 ?��*٦���Q�2���!��MN(*���r��,����ê�i��d c2v�hd�@;r1F����I���CӾ%
��Yh�ąŮK�o	�4�#���0P[o��AV7`%�n�>��
�� z���ð����ƗL.�}��f|�JhdӴ{�I��x~�4hd�¬���.4�����Z7���n�Ff�֢·r��� �l�v����D����Ȧi�������Y��YYǴ� �ln��|$�`bw��l��az7c<\!�Ff���o�����6�G��q�+��C��ہoIl����F6�� !4L��.�}�z������i�Ffߠ�������o <m$Q�~�Zb��8_؀��"vK�O���l���?�F�L��~>M���u�F��"�0�3��~3J����N�� 1 �w|G���b!hdh:P�h��[����^[jIE�Ĝ���lVz,$g	It��FT�<�nq$��6 $��*��~!��d�U�ʺ_7٢��(H�ہ��	4�ΏT�2���� JfV��\�w7@^�\�JK��F����^Xėj����~�l���~N��FC�$���fd��Lzt�̎�+��ټ��m������t2�@#[}��d;E�K�-k�$/�F���`{���-���4�e�T����nOC#3����j��&��lZ���m��;����\�5�θ[TC����kM��a#�r��_��xbh�t/�@0�����/�Q8�F��ڟ3����� � �%��4��圓�du����-c�.��1 (d��
�	�R	�l���k&��ֹ?�F�?���G>p����`�Ĺ�T��݌`kW��/FFQ�=8 h�(Q�jt��Tvz-,ʯ)𧻿%c��v �m���m�a �T�7�:����<]|N�`��C#ni,4�������X1�3%���N̑>��۟������Z$�?4+���G9Z�t�H�F=^��'��D�;�<m��ӎ���p_+�l�L�c[7C������Rc�����=n��҄Rlh���i��-Y��kء6����L���H^�j��ZX#���>w���L#��Ն&�v!�ّ�'~�p��t���_@<�����4��Hy{�_��S�Q���IUIU�j��P4�J+sJo������n�}� ��}��E�O��#5,��H�W-�	��h�a���hsw,�F��	-��W�Y ���w�P���]I��-ʌdFV�/��2 ��Dt�U�嫷�ׂ�.j"��ҽ=�J���k��@����ό� _�!گ-��үD���"y,�\D��|4>���9�-س�,�዗w^�n 1F}	��ő�z��(�3�9~�$S=]��pde��"�w#u~�U�zif? �H��%�=��]ֽ=^�-�O��n{����uo�~v����� _�&<��'��<��D��^ �h�ڛ��(�T�T��:���<mer\7�]Vp���}�M� �,x��z1�����vx[5���5��������k��?~ރ9�v�⿀�]����%/@b������,xڊ�����S1��<m�r�R��@����g)@N�j����b��� �}\��JI��:����������_�      �      x���[\��+��w{'B�[5��]T�"�TG��J^.�"@0rJ���������k��R>�r�Զ��8�'뿚�#�k�)�?��K����k��+����e}d�|j�������d��O���u�������/����5����'Ǿ�����%�4~��u4�K��ʟV�g4pE%��$��맬�/�_@�y?��}k���$�U�?sE����]��/����j��6�Gr�_��e����oM�G�|�3W�����|�F��6اֺC�����R��1@�i�p���c��?S��vl��F�T������wW�A�0?ϩ:���d#����z=q��}w"5���n#i�d���9�������*B�S&��%�o1��1$���_�Yҧ�v���#���������~�c�L�~�hy��ߎHY{ը�;$��\RN�N,=�훖ion�~�ץ,�-|�����i�~����wf|���a��r�e� ���x�S*�%->�/��:�V�}�<�:גyJ|� �����^K��[��~n�;����WR� ���U7Z��pHU���֒�z�o������Gڿ��Q��C����w��c��<�ػ�c۵�.5�ZYlx������Q��#�
�����Hmu�j憻v9 ��D�e��#������6�Z��8$�K���}�??�	ˍ�?��z��~&���i�
��'��#5��+�<���j�i`;-�:P�C���^�λ�t��� G�nh��۾��rW&���@�?�c��CI��on?�-�e9��qo���׋�w�e�W�j#�1�@"�/��<���)��*i��\w/M2�߻�L&�7RvH;���7�kQ��e<�S-��~cm����ґ���#U��W�})%�i�a��*�y�Ŭ��Y}LHx��F��q&ر]�������S�����}##��{���ዌv�:���U����g��ŽF�\]i�8\��� ��}M�qcݍ^\K�� !k��w]�>�	S��5�@k/d{aj���b	�`��ZvH����BM��~�����k��=��
˝h�n�`�� U��?v|c��Y���	׈)����>��y������F�i"ɖ�`��C���?�i8$d�{�]{����u�\�ҁ6N��W�e�N'�h��-�my$���+�[�+`��18�'�4�r���0ʾ$� � _�u�����?��~��G�(���!!��<\VY>~.�x �pMX�ٜ4S�hA��!e~sc�����V�"��ԛ�AaI<�0�Ē�d���w��s'��M���8G��U��X�1k������4=��<O�:��u	���D�0��w��r,�*�8����4�Gj�Zw��6 �s�′���$]��d:��J��i�H�����QpI�ۿ�Lt��CUgo{(v�š����o�����H���]�{/�8��� �9��/s��u�Z
��JS�nt���s����F.�����d�;]jv�X�[�Y���7q��SLxg�1$|J6�Q���)�?���]BZ���<뤹�-WQ�4��H⑰�c�E�e�J|r�?�){��DU������zO����
��)w&�U�q����Y=��xʨ;mZ���Uw��[��k� g�{�0v�z!׉�0�gw@E��O�Z�u�E�mrs8$�� �?Q�Ǵ�A������,�T���s���l\-Zu�r@zZ˲��.S�%	��r%����<^is���"
�%��n��w���u�����c���_\AP�$Aq@���>��3I��+�U��ɲ���c��#}_�\���\�dp5��U:����,�d^��uTPG�)VL�¡��&kx��jr���mʌ�?H�!��x!G����i9��t�Ŝ��?��r|�5y��}���¼�w�.���l|���~:j�Wb��db�a$e��y-�5���S%���{߸aʬ&¹&�q)�:������罢1pdxFURsP���N��I�4��<N�%� g�A�A��kϬ$�$�rI�A�d���Qd�G��<��j��}�%cU�Jc�A��)���rP����F��dv��LYT��d
��{!��\K��!�I<3�2��d��g�Wܟ�2��ʲw�f�;��j�c��2��ݛj�k�Q˖A3�c5~R�!	O����+�����j,�	(Ve|k���c�Kf��E5��f�`̢AD��l�F*�#wf��ꨄv9^�����s��Z��o�Aµ�ҙ@d��>4�@��^�x�Eú�כ{sy=V�f
�H���ɾ�w�A,�	(�=ya��rې��hf�}c�w���+�#�2��� �YM��4?�q�hf�(Z�,T��BKT�C��4Q{<����͘�Ʈ�� j8(QH��ƪ���C b9M ��X�߯��^�*n���C��
�`A�Aeո�H��<�~���������EH␴�?���XO~�����k��^n,,���c�,���I(I�6e���<IFU�@s��b)��k��Y^��r��L*��&� Ɇy&	
�fg,-مsRk�e67TfId���د�S�_
K"b���
Bϰ�z&�����B�@-���Rm�$c��-����w��;K�\2?�Xd��?�����\w�h���-����	{#N�sS�H\U�=Ʋ���n�o��.jA��Oܲ�@�!��˚9]��;���� ��7�����-��񓲜�`x*j��.x,G�{��p��اe��O��&T�H�)�]3Nٷ����₴�g?�8R��OVF����� �&9�P�+Z;��y��Z{�)e�Ufy�]H�r��*.S7�I��Ol���G�́H��ڊGҤlιO��:V�H:#�GO(�@P��n2��d	a�7SW?����O����r�8���#-�d�;�ͥ��^<���ʔ�̹W5��U�~2mz$M�ʺ�N}�[C�Va�:�Ҭ��r���'�\�`��e7���0��tqP��0ҩ�5���⫲���(�ۻ+i�Q����{qPY9���r�	���]U���8���L��*��c �<Ԥ�j�f���+X{wHPQPTz���%����	��]M�CO#�eI���?��u��v��g�k�ޗ�Z̿�K���k�|��X�ǡi�pO��0�UI��Yl]�s��Ue5T��O�2~xk�!#��T4�O�;�-�4��J�gU=T%��+U�w�I�LyA5E�`�_�-�#��vމo��$�����@j���V�Z<C��1�Z{oߩ��y�z|^L�Էi��I���o��=9����دn���0��M�H��T���������jQ�[�I��A�K�l�7֒'>i��A
q��
e(���\�;��Gw��9��>�͏�����<Wf�P�w�g�j6�R��"s8��|�~M�	Єʹ�ٞkhG^
�$[�(ⱂN���w�@���V�\���f%���Ў�|�z�X���-�P��Ze��5д������d��Fě�FU{�S_�AU&V�������QdU�2���+��yjJ�����ߺ��$J�CU����5i��)��#.���KPDm�Z���Wsز�>� C{�㶙�����Z	�x�a�ƅE=����Gb����c��>�z�W�:'�P(v|ƀ��&�L�k���R��L |J��D6���؋��~X�cUT9�^bM��{95!TW��B��GM�a>���\�Q�6v!A��F�Pu���n�*�D�AN�iɮtd�����%l�r�`�K�|��;��E����$�"A�4�\2>]��
s�l5�\ϐ��o���ʋӊk&Y��b���k]3���~t�T�d 8��e�͙{L���z�Ʌu�e$��R�Yl�/~�c���et���F��9�3�a���B��� i8�\�ܰP	0��5>8dK�&��X�˽�p9G/a�����f���\�4�X�b�F���M�kJ�ח����'���&��8(�3J��c�ڋZ�}���    ��}#W�]x2�!+�\<K�/�v��[��SH��CMtQ�<Q֛�<�~���栲��A�[�v�G�:���%�(����ǅg�H?eT�����^��6�+Ds��	/�;��*a��M�������,�r��J��'U��*�њ��kf?F��Gkl� ���'�B��n��D�uą͸�"�ġ),2�R>ֺӻ}{�S��ن!U�4�БߵnRXy�ri
B�	�vd�P�5�t�����M`Rn�H�o�X��U�����LG�f�\�C*L^(��&hoY����$�TWC��g�359 �à�F�2l��+^�����q�w�8O��](��P�h3��N�l?���LG��:��Y�	�q��說��T�H_��Y^��8�i���}I�{�᳴��4dˑ"�[ ��V^�}�a�@�)�a<���n4��h^$F�$)����~�=�U����!�rP�ƨ���.�ZU�#�$)��Z@dԬ;��^�����k�	�4�.
y�X�,)�(�/���4�+�Q�'hiR�i6'��!�4O�qsb�4�B����{�V�Ӕ�p��I��T퓈9�� P˓�L�
�D�Z�U1x�5��P��܆
��7�)�
������uk���Z���eK�
���?A_ٕ_�s����I�5�� ��&z�2	T�	Ɣ�駘<6S�$)�:�����M�JU<�~b���Ow��P6�ivC��ٖu���Ѯ�s��u`����eI����q:h��,):B�x�ufųb�SXd̖&��������˖%U$zC��>ѱ�"Ζ%����3���ʒ�@��G;�ge��]��X�H�N��/�g��?��r"[���K���e�)�R�u>�+�\:t�b/jR�,A*$	�+�VV�����ز,C������^�d�1�2�xAY�b�@��S��BYA�)7on$X�]�ٱ/ƹ��G���Q�ê�v��<�� ���B�iA�g�~�����'jP��_k���bs��X��b)V�*��{Ò�@�D,AJ�������BY�꣢�
U�J���l팆G����G��x����I�#��`���b��SB��$d���XQ%�qY޲��V)*�i�;,����l���V)&�����Ɲ=���ݒ�@RR�L�c��Y
�Ĳ%G3�ڢ�3�}{��:�l��L�C��\#ݎmSH#gˍfV�Щ2Q�r+^G6��dˍjёc �����l��%G�|�t1ݒ��#_��(���k����gf�OT�վ�A�}sH5H	�aK��Ip)��S7�dl��N-�;�*(򓉴����dɇ:��X]���#�L�3/�ʹ�ĺ��}�(����xŲ���H����G�9z��ˏ�S���f5��<����ڮ��栭�CH�7Q��ˏ��%���`7PY٬hU(� �&.~�%���>���+� �6�B뙑��W�*c�)3XuÕ�D�_�9+�!�Ә���-p&WN�Qe)R�)��	��7�E���H�eH�ʑϓ%��u���b�L�^��7�����ᣲiV�Z�wrݖ��ٙ����N�(*���ٺb�X�T��P�a��/U;�Н���b T��eJt��y�(i,�&ş.<����߅ǵbIR�Օ��$���_��D�#�����p�k�	��	��wS��4g�Aη�gs�V�K�g`my�;~�Vi�o��\<��\:::lKc$�"K�5,b�ʌ����ä�n<P�A�!S���k�����#uY��U˕�����v��CM���t2�J�5=O��;������T!���y9(����	�VY�y����� O'�Um~֎v=��5�B�v�	�vI���%{$5�hl����B;�����jԜ�.J�y��x�FP^Oľ ��#��^��St��C�VT!�{T�^��IT� �C4���/�B�nщk�~�8>��3��>�h:�J�on,NX�v�rfz��Q�fl1����I1<�r���=+��X	ȩ�Y�j����6���cWy�4_jvH����~���Z��%T`�F.�#
N�b�EWU�ӹ�.q_	�s��+�>j�n��ذ�x)*�b���p_��8r������9�Mw#�5�'��}|�{�0%�DҬ������a�m4},�>��ش�<�������@��S $�h�.*Tr��HqK�{wK���ƥ�0!��;��z��f#��*eAڜ��H�Ɖ�k��;��6?���A����ך�j�zϫ���-=b�IwX(-��CǘM�:�l��І���/y뚌����U�A+�PWf�X_����/Ś��td���Y��a:=9�&Z�@,,SROa�w�6ة��p���T5��]���rc�^�dY�B���8^�,�(�}*j��ih�n�5�^���nTfl�`< �G�V�/FK�tSQ8}[a�л�*Z��`̪��]��g) ��ZЩr;��6%.��>TU�z�a�I?Z[�YC��(�]4۲Mzj�"���sZ��]���=�G�'y���^����nk�TZ��A�/,�	��[���+ιW[�w�Q��d�^��G�d���Th�J����ĉ���Cj�Ú�WI&��n�`���"����fɫ�X�R��u�&NV�WS�7S/=��d�PY�90l�T�5��E�n:`o�iK�d��(39�RuDھ�-��o�Rh������B{��ٙ6�:��cBU;GeP��h���z�g5ڠ�{���F����@�l$�;ڊ�z�z��̄-�Ojo�P]����(>��:k�m�v-�3�c<�pP��T�g��y�z_8��L����a?B��MDxv����D>I��D�]��9d�@�X��9 7FgPA����]E:�h�$�o��w�l�Q<[�AA�)22l�ఛ�X�Da�!Ey�!��&IRuH��r2�����<��jJ{�W~�^;f��b)+U�����c`b�g�g��0G��Q~x}�����C�
=8�bZ���8��s�<Ԋ�ƍ�jZ�"�굚�Cj�c�,YP�q��p6@�(����`���I6�i[+chq�-��T�pXN*)s�E�@���b��定�����s��U�?�oKI���(+��aRF��S�RwPHc��S��09̓�1�'�4n�[Ra�#��?�P	�e�OF��H6�+E2�8Ȅ�Gv:��I9�b�	a�re2,Mf�\X9��D'�����X3q�	+>ٚ���,W�][#F�����_�ۉQ�-�禼:���z3�e�	��vx�����JsPM{�^�X`~}|�e���g�$�{�ǴrU/5.��Z���	t�Օ橐
��*�Aq���\�M��3H0�ZJ��&���.��@�mr��׾��e�pz�a�e��
ۦv.�.�X��B:+���p!Q((+���9kq	�&U�=ؽ��ݞh����_�4)��[�y��Gn�����jYRH�E�:��G�7j9���#�){�>�fk
�&=��Fzg)��4��N��9�1�eI
�1��C��?�1��rPYG:rD����ǝp"�%IUN�֫�����%xTn�	NFl��R�{���k��%�9U�t�P?u���"�}	z�a�!�0Z�k��$���[C��~�Y��¨�$���6�q�B�4�_,GJ�C�l��t��`�<��r��`���L�Di>e��c��,)����3�չ�6Շ��g"��*vگoh!Y~3�$U�1�` �����,O˒�t��Q�&�2ۼ�@�,)�(����o�?��@Ut�eʷF��u��і�%�B�nМ���s@y�$��W�;�Uܣ*-��W-I�] zQ[��NOʏ�D�,��R@I�n���N[8����s���t$U�B/��m��Aa�e��
���@C4cF�Z�Tt(a�P�U�#������0�G�8�9���dK��,<�`�KU�-�*[<�pr���� �:�FT-M�P8�a򓩚����$UK��Vd���#�YV���J�<�P> ?����n��Q;5�:��&U�8�]pA�MI�6���!:�QH�vk_:�F    g�jiR�p̪0=� t�=m]�,i��(�����U��E�jYR���;��V��5��Șބت��MU/s�Y(���(��7�7&R:s:ʬB�v��Ҥ��2gnC�+v)V�d\��<�N�a&��7�HYo�q`Y�����f�'s�d�;��3�ـ̪YW��bǁw�>�h�d��z2��d˒�]��x�5)q�	H(¨�&UGk��9uޚ%s���dyR����mآ%�L�Bx�<)ݐ�@(w۹��4���Ij�{o����=\,M������ð�8�LB�R�4�NCא<ݫ�<��v�;M���9�Y"��t�D/��<0�J-M��h����l�U�g��Ҥ@�g[NX���X�[��X�T� �v�-�����I��`';n���;%q�ʒ��	(Jd0緓��?FP6�˗����>��3!dn�%Iy�guô�͜�ӕW-K�	
R6�ff�6c�G�߲�:�J��G��@�B{�b�͌���2�gܺ��8?.�*߱�h.V�п��Rܡ�����[X(,\��j�_����/�ԡ�_&>qQ9n1o�H�E�cEZ�f�ҳ�����$��6���t�P���&J�z_��Ir[z�����=2�e�K�X�b��P�`��,��hlC��sU(*���Ќ\ZUB=&���i�Z?y�9F�׊g?0��(�a�>*B)�
0�o��GĘ,S��������qBe��G�K�r��E+����ݨ��It�Z7k����P�	��mDC(=k�[-q�6$��LI����X�,���ڜ:�tf�F�5�l'�~��gqq���n�{ ��u�+붞��xT�mi8$�.]͠�����4T�]I��z���B������3�*�3�x�j�<N��4?b�F���LMl���@�"K��o3>&7g�^��):��Yb|��_���+�N�3��M�GR����2U����Κ4�LE���53����=ܵ�$���#w���'�j'�j�CHC5��Eɚ&\��<鼰b�d9(�vʁ]�6U�+FtRn9y(."e����u A��d�:�<���@���X�ٲ�uux(��/n,[=���F.M0��X���n
����ac�Q��B��`��m�W
R�7L�Pg��|����A�X�|�,N�����
�^��
�C�GH�!���f�H,6��y�Ȍ�{������*6֩S��::����|-�����	rw@)�-�JS��=.�ӧYR,�[��<Gm�!D̝0j��%�=��h�z(�G�Qr� �z��^i	=C;S [��Ƭ*�pY�i4C� �d�R}X�h��pP4G�]9�޶VE��P����Pϰ4_`~87;�W��K�0}Ab�cV���yR��|��i�~���7X�CqƆt���w$Ǫ�V��"YZ�W��M�6څ_��^�G�+��*=&���U{��%�^��\�+y��m{:�aZqw7�$}ͧ����='ZN1_2��oo8�L��z����Cϣ�9Ǡ��$��+���v�����V��j:DD�U���Tz�Mj-y�ŏ�c��h�t=���w�l��Ƭ
���G������FכC}A�?4��v!�Á9�[C�a���ಂ\\��Ł�'�ӳ-zFB�o�^&��S$��'��y{�݇g�]�>H��¨̌���P�֦G��T̻�Ն��p�F�Cb�=�4�tN_�BpU=9(-Q��L���R��I<	�?�am���]�Q�N���{�o����{\�j�8(������>qyN���c�L��0�	�:���߯��N�K��&T4dK��w���S�qҌ`%i�3�*?2F�C�i��L�f�2}z(�%����`�S�8�*[�W�a-�)��
i�ڞ�F�cu�k� vh�5;L8H�s��LƳ�ۜy��Ɖm-۸����P��F�P:�;}O�R �!�{���h��,��V��8���VT0�fNx�@���F��Biv4����u�a]X'�i���<[�u�ξ��d�n&m�tA�C-�A1�yk2�f�ۛ�
�*ab�|�-(gZ���4���u���C!d,u	U�0SgU5��
�i�,Ꜣ0��ث�ѭ��e�:po��wW&���>��R���C@]���~4�[۴��ϱa�y۰A�Rh_��@_s��=&v7=� ���O�ϴ�&�C�iz�ң�M�.�:sI�i� �Qk����4Ը���9;�G��ңR�:����#B�t����7թ7�*��0�o��S���>WZ�	l[��:�J�KX5�)�i/x(xi��*f��������1	�Yn��]Mڝ�G�2�i�=�Z ���[M5B8�3�]-9��UM[��כ:��(^���K�U���ݒ���`А���ZN�_ȉuK�*Tdg�u��������18�_*���p�!�P���8�L��>SL��Ľ�ݵ�U���p��=��0���F<�:�/qB?É�3���:*��O�կ�6���� �.=�]�Ǯf����a*�-A��ة0�.SP�q*��P�_�^�oD�G�`��v顶�a����K!U�-A
����ћ��@�n	R\��3Ƶ��v���n	�c)�9�-S:���'h	R�n�����t�~��a�[~T�����rw<h�m��]��ҎM	,��1G{E��P���+�������g��C������pJj($��C]�3��~��4⇜_�>��������h����>ԏ�>��TV��0���6�j��Ns�=#(��k�v�j�k�eC����3�8]J?>v��\UsP��1���i��W�8��;(�,��-�`��q�^���ВUA\l5��B�Pk�-?
$�=(3́�;E'$��G�	��K����w�
;���GO�*��׈)f�ևS?��T�B�/Wrv�����*K�
��pF�Δb�3��`	�=P�C7�ϣ�8��ՙ;����ͳ6~3jvˎ����W<Wh�|!��f��� �o�#�&����ݒ�j'�z7���,8#ďj:��o&w�����>�����(�zx��݋+M�Ǉ������>������wYqK@��(�8���++˖^���R�n�Qu�- ��l�Kf�J���Fq��t�Bx5I�_�� �z(^T�qE��8n=���YB��m� e�R�L��{(���ng[��|Va��3��������N�����ǭBAy��Ǆ�	��GU��bP�k��30L;,=�����ݕC������n�Q�XnUζ��]+^�-;��z�20�T��0�iG�ң�kW'�*�6���?�B�eG��Q����ʤg�^�}
ݒ�d�����ֺ�c�w��hV=�7�z�8DY��n�Q5��_��Q�\��m|�=�`�8��&/l��^ݒ�:_
��T�g�A�&k�ݒ�����%�g
z���n�Ѭ�{zv�I2��ħ[K�f��%�Ϙ�sQ&.Ė���oYkx�:.��wK��(�4��W-��[��ݻ�G3g���Oc{ĥ�<l���Gu��Ki�+п^}%���J�Ϡ$ً�x�	��C�Ls��R��=�*l��L��%�1>�poH�r�P��_*����Q+�L�~3�U�B�ުPu��<V<ˎRㆤ2��4F���0a��(�]�F�vS�ّ�An��k˔��5�Cj�,�ң4N�O�����د�ң9�Bj.4���u���G�	1���^�ҿ���_�eHs9i�o�����x�j9(=�,Ӛ��f���n	�L�Y�p.��@n?�8�!���P��܆v7Op�9m�TvPj�X0�Y�=�0Ǎ+��d:�:H���j
Xqy�nW#���r���:~u�� �y(�^q�%�#��H	��r2�wnAճ�w�t�T�)R�QF�g�"��	̜
���q`qp��v����<s��B�����8���v�O�3�����w�4|�;�U���j�r|���RB6Mr��9q�P̮��������X�]� ΃~�ө�<H�bS*��j	�z��S˗��<y�P�q~t3�    H%���ˆy�6����H�zd�!�ݝZ#�p�4Eb�J�'۵<����6�ǁp�)y$���ԎwW�aHN�$I��PT���C;�Vl�6�|�������u�@(�Ӷp������.H����hm��8�+��3(����t^�ĕ�����p���f�:W�0F��ΦL+0��.��@�^�*<�pHB�|�{���5��ȝ��CB2�v�T���&��T�����_{}���W%�
��0�ٮ.�uCe�p�����v����j�+���u�&�[ߒO�����3���8(�+���s�V�q&Y��Y�Z�q���0&v��2#.T{�L��q��Э�"�*B���
�4(\ۉI�!,�%�3t���H��x��頚�C�:/�#+�mY�J�����dm���NE����#q�,�4�~u<��,*kYPhw:D��b��fȉ��jd���������F.�2�&���d�óð~���Z:M�V��xX:�:�!�N�n]0	�Pd2~3�ӗZv�2�yx$��.�h[�<l'�u���g��̺��ߟ�ͨú	&r�Bǘ����z��P�=��A}�B��M���,���*�0��[�6����O��9�����⅁P��ҥ��Aw�	O���GS��ұ	�1�l*��*��HיP�\��*s� �G���!�z�!�<�����0S���D��NQ�����G{/3>�;�;8�8�6���ȿ�e��rNJ�Ж��׵ˉ;aib��JR���qw�Kz��V�@L�@ltk���Z{d��MP���EBJ<Mt
��aepX��OSVƱ��Z#>��b����D�ׄ�Y&5�6��o�6�鴋4OܸGvG�Z�a�u�u�8�g-,���>��Pl�x��{z��@���-�%���<8w�jlv�!�;��J������'��ê8�(Wz�.��NBrt4qH����"}o�=�V��İC&u<{B�yoX����F&�(-��_��0�[�P��ɕ�n|��<�gFk	'w����ˊ�,����E��~���ʧ�#zT�C�/L�t�1�L;��j:���8e�{�欕�Oz������2�ҫbozXN݄�����n�F�N8��#-��11�ٽ���Gc��842�_��7']TqP�U�e��͚����GӫG����D(|N#���y(.�h�*�&�����hÂ�ܛ_�NbK8���į�k�'Zܩ0�ͳ*�)�\���;6��P�8�rP:�K@H�mN�/f�
��H�"�{Ś�w�j� 2�x(�?��N����ưqNǭ�m�R�����_qP���|fm�Y9�\0F�H,��lq�<�y*�TsP:�Dp(��~�1�d��
�8T�@�e�i����\^�eR�O�#Ǿ%cL��^M�ҭ�ml�����i;%��$�qP\6��#�y΂[E2�����:�����Z�i����k�#���_�srK�{�7��|B7ޯ,;
�,%��5�V��aƒ�G���K�V���;CK����%��w�C:Ï��eF�E3�<�	��1}n�Ɛa�Qa%���l갺���aK����7l������R�?~�M�=^(�7��&��� ����m��c�-�W�z'���Ε>��̒�����b�Q�S�5���8�=d���FuB(�˲�T�凈cXj�Ϭ�}Tk���	��S�Ԩ�3�=d��&�C<���N% �i{��Q�DH6���@����ٻt*�㘚*���4lX��5ˌj�T�GL�fc��b	ǴԨ.Dҡ���zd��8��Ω���ە��ޓ0������,�S]dN�"aZj�L��EA��o���%�n�+�x9� ^�d#J�eF�{�b\�ݷ�#�i�QQ#ȇ1�X�.=}Χ�F��V��.����`���II�F��G�)	fjjB-�ܨ��m��FM�'z��P��Y	�$A�	
��c %J��Q�f�T>�GXᘖ�_�zI4M�m!�AK���&i��SC���䨊������ķx]p��t��
j�>�®��oZnT;�A�s6�2?�pY��hN�a�0�k��c�P8HvZrT=�qR��Z���YS�hU��Ŧ�o�f�&6��?��MK�� |+l=4��qO�i�QUm��&/�Y�ӿǁ%GuNv4��v�-,�NK�j�?�����5�c�i�Ѭ��?�m4�3Ӓ�*��C�7�zzBntZn��Nf����k����%G�Q�hږO������p|X㔹	;p�N1%���&��o}z�b����U�Oˍ�����ZeK����j�\��<Kݫ�!���fh��m�@/?�i��LӘ�b״ݱ���Z��FU!M�D6���'�ی�F!kVF�dӯx��cˌfu���Tr�쥞�QtQVP����g���v|�vZO"�鐲�'�v��f�%���>��\˜�ڷ���X=��/�{ɳ#'t7��>����Z��MS*%ϋ=P�4am��P���� �JXF��1�m3ֈ�Z��,���9锲�<�i'=��BWy�����0� ��"mtx�UI�1niZmE���W��2}����!��PZ^���K8c��͡.��@��j5K�J����l�AA[�sx:1�*P�o��?���@�91�`�@���6T��1�ǾA�b�|��*{K���e�Օ-��Lk�4O��ʄ3H�LP
b���j4Oh`�oJ&��4\?[�P�κ�2�A�S��<Ӊ��W����fB.�µ٦��֒����JU�'G�rPE�lSɟa�5����w�'�T��b�����#r�X�ǥ]�e w��S�Y��F!Q����F�6(��9,��^KH�X�4^��X��8֑P'�`1 �Ҫٔ� )����B�ӕ��Xe�j��������`{���3���X���`ډ���R��>˯.m=��n�65H�i�f3*m/	�<7悢f��� 7E�&�)bצ�>�BldK��8!7T9�a#��H�6�"�>p�T8�/�*���$T���c�]n���⠄��
��2�{&�WUT�56�9�%���zHS�
c](P-���[qF5����>߮by�D#Ÿ�0��bi����߈dy�6�'� C��7��GD�3�X�PZ���ٸ[��)�MTR�0[�{	�k��⡚j!3��w�N�h��1g�H��d��&���e s��:�@X�=��b�t�lZ]:���K��,�X�9��#z��r�lę��@� �ǚ3��S�Oف�:�g���*��!�iJ`�+Ojb�����L���Gb����.R�#oߋ����\:�e��s�/�}�4��a~��a ,�j������+��Q,qc��1��%�T�Χ�hg.�:��m;��c��L��[c�D��b�J"s���"(�4�bs?=;�A-��5o��Z�]�$�y2��{m���2�N���p&��iϋ�jy�uh��\���c������*���0�6��L��CƲ�k!�M�v��E�<\�V��i3&R����a%)�V�Z�E��f�_R��9G��J�C)�U��J�M�یwҕ�CRmvE�m�G��t���C*�&8�4W��z!�����P�ݿ�dtF:k#l�]vH��Uh.8L�}9�6Bc�f0�,Ⴔ&6�#E�M"�mI�P��a]��S�cز>=�+2l+���C�v+���v�G$�fߢ�S�T-'+n�H����mi�.Cqޒ��m�B�|Z���%�A���6f; ��*qX9�w�g;����{R��p�r�O�H�TW��&��¤q�tP�����|��Z|Y�<�B`�m|�����H�rrP@	FD$����;�ɗ��7�> �ޚ�[�,06{]9{��$�e�;�&�^����c&I6�s Oh����Vw&C88-s�V�Pxj[Nϐ���&�v��J/ôc���{X�ge�:�*�=\yx�΍W8n�;�e�����p&�죈�w	��P���r@%sp
/���E&g�$���O��pⓊ��U�A�3�t�kw�o�����W�k��ⷭj��~��:U�&g������V�k�cO2'�    ��w��1Q;ViIG��!5�(�!둝��ǐ!��n�꼽8l��n��yP�ٙ���f����8f���<���H����3���Ǭ0:I.K�J;�>.!�	,'��IrY�T�)�8�wQA��u��-ˑ��ϊճ��T_�OȲ)K�<�-��꥾aa(X�T�)Q��=<̧!ǲ��P��\��t>F�o�{(���{�Id)	G�,ׁ�]W+c�u�&T�$�qt��g��j�ͼ-���Z�B-C��m������g9RÃo�gZ����9Y�?z��$�fV�S�nX��!)��(N�Ʋh��,A�!��u�R��|?��ct�A5�!�L?T#�����2�,C��r��P�����d+�xX�!=q����
!Ž����t^Q�5�����q�C�@��inڦ�h�X� ���O�a���gO�OY�Ru�XO0}�IM�ër�X&�<���y�NT�CH�-K���:4��vw�7�FLF.K��i:j�<TdC��8��.7��;�F���pS����h93zn�؎�A݅'9#��<�t�����(!s"͜\�9,Gz�ۜ#\�5��ʿ��̒�ؾu��"�Db��+�]��bS����:�	�ԸcY�TXˇ�e7�g�N��^�#�_�������`9\@-G��ړT7������gY���_aÈ�=6�O&T@-K�fU0��B��]�,E�:i��¨��=iJ��%H񪅵i�]ڴO��˰p�,A����(���[�;��r��Rƫ��{f5��L �^�T��(,�'�Ii�Ci�,E��k���Oi��E{C�,�R�j'Y��2�4ݖW$X�4������n�V���Ï�ʻ��� �$�Z^�.������՞�\蘖ݓb7gx{�C�xZ���;������&<�X�T]�T�b�%I3m�è�$�*[ ��os�n���[�#���N%#�o$�wGF.ˑf��$���;�.��O��i�ԍC�@���S�o��"ͬ&�R���F����Z�"�e%h�¾�[6�N�r��r�Y�x����S<B��C�)�X�虬�ж�Y�U�9R�iu�'20G�K˙�����4J�[{~Hz�+r��s5q�SR��p�ò��D)f��LC�Ӄ�q�]�A�&�5W7@�&����/"n�r�dc�I�,��֜����^���� }�*{(F;W�5Γ�l(/A�*���N��h��Ѱ��/�[8`ة(�M�qY>�'<���m�t=��В�|�C
4�K#�Ւ[Wy�(�X^����W8'�j,����j:(�q?���F&�s�Bk9(���0|��u=݅�6(�"�S�/�J�9*���P6�U����ݜ���}���b�ԧ��󷘆�4�|7X���k�tEǐuz��!��E\셏CwӂOQ�ߡ�����f�7�������Ǣ��T��ɫ�r(��X�aAFfg�y������t[a��v�Y�¼vcِ��1�'y��3w�Ѡ�m�r�X]:X#�yV��,[�W��p"�Y��H-��KRοX;e{R�����q�����q��Y7�#���&��UVa�>L�=�ņ��V�R	�.s|V��}���h1�R�Z����%'�8(=��2�5s����(�P�Cq��?���u��}�7��L�G:�^�Q�,�؈�����Z����|țK����ƅ��Ґ;�T��ҹ���Jw��Rl%����:�Y0F0@�kx�_�@�#�8a�Q��m1���l��3���(ܬ��B|X�;�L_����S��n��4gc�EZ�fj���8H��PEg�#��ה�0�VQC"|;����du&�p��vn$w��lﱊ�����F�BoB^�q���ZQR_��z��=`cِ�-��=��pÐg�Z�x��Ӟ�>�C���{h!(�6E�Q��m����!�v��3�Ь/nׯ�Rz���P��J����|q�q�uz(%4��,1D����T�u�Ld�ؼ�ڟd��0s�d-���R�	��b�FC���x7�x(���4P�Ӥ"�챔��\^#anG���6VqX�A: �Uld<�G�Z��D;��bb�N��4jz�9[sX`�p��D��W�#��HAK��=Im�>��G����j�%u�)C�~�P6�'`��(rZ/29�b�E-����.�Vɕ����{�X:����:��K</�#��Ol�/#������́#�\/u�^V՝3!�CJ)V�o��4G�&�K�P����c�dQ�kf[�]E�n#~Qݍ���C�w�H����Ţ:���sW������tj:(5EF�V���9l����������y����<���p�R���z�CVeQ
�<�Bd=<�R#;(�q6K�ɇ���x,v�6*�7r9��P�+���1��ӭ�:��E��9�8.� a�f�h� �Z��&־��#�������h^�oo(�X�ڢ���Ť�X }������<�M��69U��P\"i&�x�/�e1�N���K<Vg��h��8J7lJ�&��a�Yf��ԯ���U<U�}6KҞ�P�!iV����j���U}�!\C(?B����;�_�c^��h����Ӿԩ��ҏ�R:t��W��k���J��Ai�u[\]�m�sy����P.���V��Vm���#�9s;�_�Z�U^J���b�������챚
RVÊ?u����*�@0�&�	ڃ]h�W�l�>.�xar��wb�M�a5���紤~WT,6��}��ҴX�Ok�3Lf#���7��X*���7)"Go���\kK�XPp��ٔ<�3|�j�i��r�ߦ�E�>���p����duD'ǣ��J���Y��ܹ.�iq���8� ���:MȽ��c������j��t6���u�s�x�e`5���t�4t�,�X�ci����9)L*����ր4u�sϿ�XVH9%#V��D��بA�����e���ԥ���<.k9,9�R0&q�����@,+��rY�M��e�Pb�Ǣ�EДf�L�������'?�����o+��V�X:�g���F�u{�g��Ab
u��f�r��K���eaE\��$��L��\bYXmB�[�0�h��{���~&��uM��w��9o�n4h�X l�?,��59��6�<�XV[�V}�[�;|wt%��=�0b(ݦ%��CG��%�X �1��9*3I�Ik�$�P� *���?�gtYV��z�Ŷᙵ!�MI�A��e�Ncd]i�y.��lЏ3t\h0����QŲ�2� :cxS-�-fj�BA��i�t�d����8z�#
��8�<���]���[�b;��8�K�
�l&���s�3`9>��%b�������z����X"VX��q���@��}�щX&V�K���c��y��7D,��D�;��%��[xY�C�0?|Dw���%�W��b�|�P�:�]�θ	���{,�Ŗ�����ǜzK�jzT`�R�q��
Z.V��3Y~G7���ku�\,����;�4����V���"���OW�v��7�'��U	f"�y�w���n+�ŊX&X�~#Ц��Tz	�FD���B��2�B�}8�D|f��2����R4�X"V� h�����7�6�c���%b�_��"�6[�d��O�2�9_�Nk[	b#��x`��L�42��������GpY�i��opƕ� ����%n��d�'˖q%
�4D~گ2%�����'�7�X1 ���:�q�լ���D����؇�1[�2��(�WFo�X]��h���yFg=�pKĞf�aDJ���ھ�����J�L�T��+�<��0�1�ʮu���K�\~��=To��}o2O�S\��]����}�7)O�[&WME4��A�<����+����Gr�(���<Ƅ�����YVq�W���`Ad�A�N���\�P�Aa��;jؗq]��0�y�9�D�NNG��.�LP���(:����ￓ�R�%���jt�T���bބ�wjyh5�x+�)����֦�F5|\��a���w�E(���%�/��}$���G��������(�k���z/�r�    ;�=|K��4�h�L�v������A�8B)wԔ�ՙ+?F(m,���1�߻��8���k\��B��U���d��Z3��/mC5EW��a���_��3?�;��������.ݝ���5VQOQL^�PsS�C�%�r�h�9�ҿe9>�����`�7�iTr��2�bҋ��� J~���2�w�@h:���aUMI�j���_v鯜�29>Xj�eϭ�_9���yuI,�>���]�<|�����"����A3�u\�>�ѬH��$��'q�ࣂ=}�K)pͷ��Y!�+%�>�GJ��*(�u�;�lȓ�pŅ�Q�EP��
�lf^�z̋�v���C��2�������h�2K&�Ԭ&gT1��i�}�+{�I5��+֡R�U�_�aa�Z<��b����)*���j:�uT3D3k'\���j���3CT��-�g���������+��i��%ro0�T�
�A���s:�ڏTp���̅Xй��̣�����y���^�W��G����c��P���p��"h��q�dc���8����Ow�����S�X�{(���\�b��i��T<�֌�Ӭ��)k119r7�)R�~J7.$hZ�I95����
��F�1��S�P�u���>�̳DĢϻ ���",��xQ	�||�9M�Uh^3J��{�|x�0�Pj�^W5z��5�-�dhĂ��|�a��i�/��#?�bC�=���)(d��p�o��f���.�a���ʃ��R�(��}�.ۙ�3�7	|�X}��6q?v��\n�B���r��L���\�����QAF)��F#���k�����Ns���Ph~���/����+<9�ϲ<T��m�{�>C�|P]w����b�tf#6���T�d�ه�i�j+�{�('��V�!��.j���p���w�ʩ�}�ί�Ĉfk-1���y��������M#�/��j�ԇkn��f=�q�>��Թ�^�&�8-�P�A߸2�W���Y���@����p��٧,��c����QM@Q�F�#�s��z+o-��ğ�s�w�?y\O�E~��
��r�j	�㙖rOMW,h�h;aJz�Hb��k~,۷	����Û_nU�bѥ�$-/��(�`KsP�s��0��qc�Z���s�����J@�9Ĥ�������t��~��~�?=���G�{m���@xY�a�j���:��oq,P,���}�����i���.�Eǉ�x�1m��Dyu]�C���!��l�����H3�WU<�L2��oO�,g/�O�w��`1���@�)~%7�y���e�.���|�q�,�"<
�����)��Q�q]*��X]�,��j3��/�oq:,�u8�b/��wL��g��5U��jĕF�
�_m�75�X�pE~}���˷:�ű���ŧ���r�ȁ��T8��wr����P^��o���u�Tf�l׉*��U���9ZA+Q�Ij"��K���"|�n���c�x<�������lؚ��;�ϰmx,��	�������m:�|�8Bߒ�QC�>�k9,��p�u�+1*-?��VU�w�L��%�6���>�cw�:Ɔ>T�'�}�7��j%Cl��k���G}�Z��VMD����}Է�X��
�iDzW�n����^�`�i��u�jĕ�ܻ��_#y]����%�W5T���ݤ%{j�G�bM�šc���.����+����մc������Q|�#9��9M6��~���Ni��+� q�����]etH�T��zU��ILr5)��x(�;�oKY���aiTJ�3�u�o�uVt$,��!�fל�9�������+=�<��g2G�Rf�#�墅�)~�*�K������ͷ������Êi��Nd��Ra-���X_��uF=DP����)Q�U����1��K,&����E�*:
v~�H ��T//���Ҏv��z3�\�XP��4���v���u5������A-��a�����J�h�������G�O�L��6V2A/����f���V������R���|e���n�*�審�#�_>��&`����g������^�]���$�����`�X��RR�5�?��ZP�c��nM� 2�DG�>���.����.���׈9���#aٮ���ZM��n6ñ�����۫�.X���aןj�F�;,�UKr,,�h��"m�E�Qe�Y%v,����q�g�c��e�Y`q,,����W`��}�8VM�#�A���爱��X����ba��"^��ޡ��ƞ���m��2�Œ|�7���wrZOn�%��o4{��e���f�p-��{�IT躹M��X�e�X��:Uon&F�����XP����r�Y ��4�Ɋ%`uV��࿝� k�%`u�/���Tc'V�-�P�s�������K�J:"�ґ�^��f����K��jh�R�U��*\��`��MPf)�f��n�(��U� &�h J氏g�*\��
m�3<!���L����E|����g����j.���P����LɌ��E|؃�n:��H�X��*~�ه}�oU��lUN�=1&�J�a�"Y���N��-�)ه}�f:�IG����N��}�7Z��moa�g���lس�wG���L����Z�Ǔo
�<a�$N�hi��EK�
�Z�?vC��b)X�S�A���� �Ȋ�`�TVt���z�u,IiW`xY�cqp��y��#i�b|�,���v�p����?���R���b��<��t�d=V�X:_]�b{b������X
V(]D#�(V
�._�\��U�33���hY�;�Z�J��X����nׇ��jeC>s�"�2$�V>": �|,G�A��ݯ.�_��kz,�n���,q3R���PC�n3{�������x���+Mʜ���CkS,����#��v�V7�̩?Fwh)�3��2�(�R��w��C�r�gt�R�jU�:��W[V(:F����О2D5SaٺXVݦ���tt���#��������5��GD}��K�A��8�� -_���j�cۆ�i��Ů��2_��Ja���t�8|�棾%��Ŧo���~����'����K��ՠV�{TS d�b��mG����ea�X��O����>?��;�ea&�s����|�`K�*T�G������[�����Gŀ�{�����hIXewrQ/3#����D��ǚ<�«���4'��u��$����挦�f�Ģ4K�	YVM��^�%�ѵ^GuK��-��m@�G?�vƷhYXu��`��ޢ���P6���� 5b��"���r�
U�]��B{�rK��HB��ı�>+ڴ�<z��ԣJ��x5[$-�?�ax,5�l;ܗٯ�9I��X
P:W!�Ŵ�z8�8�P,�-�`�$9�$��b9XQo��3J��������XP[�C��)g(�#Q�$���"�Ts���������{���u~
���;Q��.٦���X>��w�L	���%��e����JW����`�R��ZV�����jhb����a�ņ���۬����gx]�cq(��8Ә�f��T�X�v�T��9��yױl�X�+ �/���i�̱�q�X�c�����Z�-�o�u�<�������2���8�[V����[�����H�,+l�G�V���;,��X�am�C%ﮁ���˫�L����ht��&���|��@����܁���m�>�+K�np�&�D�T�A-���� �ʡ��*c��byX���$���z�V79��C�챲���x�iUy�`K�*�1co�ş6�x��miX`�;�)�g��=}sX�f΃^�^|�^�b��a5e/�;�溜ST☷4���@ᜊ[���Lj���X����Ɉ�ʇ
���b��3�1����hqkM>�3�]��6VȦǻlM>��j��Ūw����j�A��~��^{JVgHy�65��/J�a���t���bx]>��*��5���-���&������
W�)��b�WM>�k�	\�X�Gb��@k�a_ٻ@]�-�V�\y�.�    䣾i�w���fϙ�s���G}���~Zk�[��f���z(���A��|95���;:V<vt��1�<U���Bƍ�l_��?�)gx��ae�-�2��rr��A�:6��WN�Eg�ai�b|�����w �yO��H��?��;�3m��/�TxaQX�X�c5.��(n�:��JUk��U�ƪ�?�_��$�k䐤ǖ];xB�u�G�Q�cˮ��Ÿm�z�Z[�^�-q�o�>�u�[����x��a�gWG��c��9�b�|;���x��ѭ���qq�:2V��g"�~�_s���jJ�EjsZ�� 76Q���Ս��
S�"E.1��X�b�j[�Y���3�����]��'xO���N8fߪ�c'�$�*�f��̓d�G���Xba�!�,+H���'������.�7 ��(E���Z|���|��(>�"�X|̗��\�}��_-��i��/I� ��w��`�׾X|��\G_ơ=ף�zDD�1����Ѧ�2r�B��W����)�{so���6+���G.�W,l?Ӭ�j{����B�P�V��0��aU��2��'ζ���B\���G|�c�ɘ7�:g�Z}�7������s�n�U�u�>���$W�q-(�l֎�]\�6;UJ=U�XY�(a�66Es�V��G������4\�J�_\�W��sut,��#Y�۩?.�y^tt,%�x"��j.K}�^�ky,բ6p\��Ig�G����o����:�	��qm�::�����Y{]�d��X�P���#�i�x�Dԗ�@ul�Z�S�^��zh6�䌥X����*B���:Xh�6� �惾q�j��Zl��s���j�X�ܱX���Vw3Y,\��P��0��T[���X�[-�/Wͅ����S�qa�X`5���\�7��Z.��(p���~�qjjqpY2)�~?S���!i%5N-�u��+�f�2O���Ւ���"��j���I���Jo�X=�����x�2�����-{\�秣�`oQ=�_O�ǀX�NQ����,ް�zLl�O~N�gdZ(=3��^�$i~c[3u�T�3Y��yty�Cf��=K$��<�rl欗�Pt9cJ�C�q�&��DHK�Q8�ǌ
���_���o�6�:|�c.(�y��OȧGSR>䡵B�6��U���8��|l��)2���I�����R-�XXK��m]�P���w8�fb*��]���p�����rF,#�4zP�b�մX-(��1�)B@��!1Q-�9`���Mژ�P���WT��*����l�f��{\V�X�Xj���sR�F�/�8(| (Z�ss�M�^�����1��8W�g|�:}�k�EK@P��ZJ����Ǭ�VHw駵@�>�u�s	歠Q<�����P��Y�Fa�LFyh5���]�ă�⏌�4��|��sv�,�`�o�G��|ģ�m��\޴��B�X��J���Y-F�*��p*��G|K�UCXݧW����[��lڤ
Ð�ea�?�e��o��-��bB��]����)	��ߌ�^Gp<�u��WS��0v��E�Z㮑�|��+Uʕ>F8�u]~�ʖ�y��܊�T]Xy���`u`�(�Tl>��Q�YVǚi�v����C]d=�Y���w���+]n����L��Al���#���2�Y��Y�������@"�j��!�G��8Sgbr�Y6�FNxZ�S�<��{�d��:'k�9*�R�����6t�c�=1.57K�rs��l�����.�k�Qݺ�\��ɯj`���og��R��&>�u��<�u�~>�!�j⃾�*��Gn��9R�����G}c�O^11���⎤f)X�C�h
Y��Z�$��q�[
6��,,��bz=��iR��aF!� %e�W���#�-��N��U�{I�*��l)X���s�J�M���?��f)X`�q���5��:w�a7K�f:���Fb�+���kQn����Y�^���uQFo�-E�Ɏ��*n��:����A�	k_��j��WO[nK�@Q31�^?6lg��5��;1�J�zԝ����5��z��"釘�jyz(-6C#7�־#�����=X<-	JI7	��Y{̀2�bM�~!�e�S>j�K��9RUjLy>����8�P�[l�g:� �����`ѣ#c�p���q-���6<�῵j�mZ�Q��II�ЍX���2�V|���c$q*���I\l�G}�ȬڐZ.{6[gGx]6�9�foY��;��Tƾ47ߧP�go`q��w��kd�	œc�mW�9o����U�X�Ɨ%b�����)�jvX�F�&��a��iLf4K`�pT��pY��~~/�z(-7w� �M�"�X:�jsH0O*���3�n��M��X��R�g�10H�Vz=��*=�*�}�N�b�06d�]���&nW�����U���`�g�ę]�q����~�tO�a|m�����λ9u�Wݐd�J��u�_���L2��_����ӊ��S[�{�#�i�M�[uX(A�f�ke�@�B5��r�D�UA��cN����!����bO���[�̉�2��,��l�����6l��#�Lꖨ���:��8�=/h���㉞�-t'>��N�if��`z�śbC�n��{D�Ǖ�xX��b�_y$��λ��X�8�t�����}*R^��}�W�����jW��f���� N�aj�����ay�n,�8�K�W�z���t[��z�����>���X�8ٝ���6����<��w�=~$���B
��E)G��ܩ���^��{�x(�%H��l�e��k��F�P�>�xc���/�8��.E��L��X��YxT���q��H~�׎��|�+�R�#���ȃS�[���=Б�2n����U�	q3Σ]H�	xmL��"ڰ�c"�������XV���b6�����frHB���wX�<\>��
�0:�@fS����W��a�6
�;�yҍ-^LgqP��+����Ùo��:$l�`Vp��D�ʫ�8���9��}���~1����Y�Y�վ?���^*sσ�񮊔������VԟC�nA��C>����V�Κ�n���[��?g��=S��%���-��I{�}����IL����5�2h3nc����*�X���A�{X�M�P�C�+�L��Ö�Tp�DVsXY�D�ܰL���b]L[�a�P��U:C+&`���N�9���%�-���C)`�dg*������届����Ѯ������m��Zv�
�c2�f���[ؓ8,��U��b'�%*�㕫��t��[�]Zg]\L�x,zS4!����,\W���(N컓�qF�Ņ�����|���N\�;t�M��G3ha�i�.8����=��9~����9k\����'�P<@�N�mf,�Ǎ�=��/���9�y�~��>�޺��/:e	��f5��Z�iw�a_E���/��Ky=/�aߨ�.0�2�$V˚<*o]|�7��T����f
�1C�Ň=�Yh4>�5Fk)4\�ؠW�jx�n�����.�cq;�jIoO�j��t��W܎�A�1��ez����o˖�q���Xo��?�k��j��ɻ�����bF8h�$@�
^m�`�V��Ki���P+�ӫ�{�;�M����Xfo)���π#��*%�P�6��珞�M���:�ƚ�,�w���}�/[�V��]�� 56Uk��9.ħ�`-�4�+����
?����!�vQ���1?�Oz,��u��D߆�^��X,lV��Ψ�PN�[����cV�����s��(jM�-�s���:f�k莨骶dD<���k����,�)x�N��҅�H�z4��[~:��= b./2�f;���O����l	K!�/�*
�] 
��	��烙��?�C_�1������މ+��L���B�)٨2����f|����Mї��pmK��~�����.��؄����ޒ�x|,se����^�/i�L��rc��۳��Z��L�f���)�R�!�Zғ����~P)�m��fT� g�	���c��Mё���>��ҫC�]��ɕ���q��z���]n���9�zHτf_P���#�}�`{~���    [��B�F�D3 {~��.t���pQ|�8��+pOH�\Mp����,w;Ο�t$Բ� �C�����W�d�'�� K�&Ln0����Yxŏ�!�� B�ADx�q����t��X�*��A���C�N�v��Yo�S����:4�/9p�-��
(p`����H��.S�|uތ;|��p��Dsy*k�:�p���IK$!�3��!"o���:���LL�l�����*n���D��1�Ż���� �톍���<��m��}+p�� '���fDf4�-fY8Ra��h.Og��P �"��o#��	����6��rN�?tf�-�����>�5�;�@� n^|�O��\t������j¹Ʉd��/ůX[��cJ֚̊��y_�����% �CC��x^>�M7ٓ}[�ی��X>�U��~�ع�M³�t.���D�N
�DΑtLΜ�g}���}�[��NLK6��I?����ci���d�8�T��K��A��׿9i<�E����`*�|�)���Ú�"�������'�����9N�/ˬ������5���X����0��Hl!�?����JXp��DU(]	��lcA狅jUIr)[lo �!b��l��Q�B����{5ɪ=�G��>�-�n�l�����6�WQ�XLIͮp�%���O�E��΁+�����3�0��NA�b��y���F?-;�˜P���L�ۤ���H�G���[D����-QV���^cT����t�d�S�X���&�Xu�����X��j�\�Б�	<��S���:SP�AwL.�}����[7voǛ-\w��N����)oܕ)�2���q���b)7��!��^���5��y�(��\T��2U�Xt�6�F|E`MVm�l��`��ų��[Z����rʃ��R�r?�������K�X�����6�7���K��B��\�g�ދ�{�K�����������c&�rއ�"��T�T?*5�f_���V��zE��E׹~E�������:4��k)k��������G�g��-���c�וTi#�����{> �Ugo^���Y9׼�����߿����$�3�X��Z$?���`��;G���5kT��3��uY�a��cь��^W���lε�5o�¢�R���ż��Q��"BtF�Q�L�N��w,4�_��f���a�����N�c{x�z�~���u���]x岜�����}.>�w�+�~�#�kno�.�`o�����|��XZ`9;�A�+;�"���>�툏?�`I���S��2�g$�6���b�&�����|�|.[ǋK1�b!�߄��tߐ2�q��#�]�U��]m�.>J-�I s�*yEa�x���_cw�E[�c�yÜK�W�:������'���
}>���\���
���|���<���<��^���th>�ῆ�ĊA��W"?�\>�1.�x�ڿ�H�������t�j��S`��1&����n�.��������3N���}�}�h]1�~Ar6���k1Ʌ)���vɞ�|£���[�8��"D�W�_���@��P�?�֬8R��a�_~�����g)�j�"���澰|�N1��7T ��;���z�K�r��,`k�Y�1� ��^	泜z��x@D�}�]��sy�vL���?;̠�'��v+6��(	�����X��%�YN��Ɲ�R�&E(󈻬�~Ǿ���>��P����m#���0�C�hn)F�y%�:|�c�hD�O�b�q��Q�t~
�D�EᢤFR���5Lܔ��Ͱd���5_�Bύ?ꔼ�}��,��N����U����R �$�:Œ
w�i1[�C���*�#�ײ�D"55iV����5�SD߮X���X^ź�_�d�>+P���c��`��ȩ�h��/Ac#��>v���������jl�:��=*�v���?%j6k^�g�����Jrp�����>�a�1[���:�n��GQ�v�d��oz�2��B������#�%ԊJ]R�O��w��e�_�e4���}{�b��*5ʉoL
[��9��V�ĉg9	�h9�\dq����褅�+:����F�Li6���C�a���r����}���q�M��CJ_${����'��`ͷ[?g���|�g	�t��ݷ�~���Z�����ݷ�(�V	���do�a���;��������y?�9k���FF_˧=�,T��
��X;i-��������b��&����P�C����/8|�YQ��BQY��\ّ�Œ%V&\�=���l0�[���Z�;ֈt� ��c�!� )J{�BD�ު\�^W�����Qe�{������0X�[����Q=~I�� X!<��X5ԓa��`�%��O�Aus��F�v.�������{t(h���s|�2�˳uC^׊2��[��By�@k{T��]�T\��Z$�Zo [_��y�4V�Z����Nz�F��2���F����b*������ѳf]1X���/�ۇ�+�B��c�.���4����qΏ�`�R+[���Y�
���N�z*Ko!2�X�+���aH��V2�0g���W����FF��
�V�p�3���]<���ݏOy4�0����;M	l������pW�oV���X>�mG���._fR��n�����U�*\�P"J%"��㓾q�V\�/����*�~|�w�D�?#�ҥ�<W$"�X>�9��^�zM*1�:ݏ�zS��p\�����V+	7v+
[)�[y8!�ן�N����V���x�mA$!� y���Z�JU�G�-V�)����+�&���x�s�Vּ2�%�.�7Y�H�a��ȷ���T�~��a5���&�Mu���[@�;�����l��!J�9oG��ę�:w+
k� �8�	�р3iW���\7%�~OSn��]��0���F�r��d�|^�������{�4ޢn�s=i,��X���������ǫ���7s;�xuw�4���]}�w��:+�#h}b|�U����}��ӔMwlӴ���al���C�j�>�L�]}΃YI��**��km�4�>��4�A�?.t�"�W�������œf���
�%7ՏR&���wZq�j�L��m6d$���eU��M����&V����&����PyC���S�j�c�u��x�7D,��E,nk��k����%�V �Z S���27 q&��V0���؄ �T��O��({���4�.��p��k��k�Xf:��m��~��'�Ie<�t���[�pl���V(��k� ���R��J~|l)[)���0���Z�+y�ak�[84R�����0Vs���+�����+�1iq+k��x5�w
��6j�q��Oy��V�����I/����r�=�U�%�G���E��Ծ|,�n�t�r���B�\��b���%U�/���n����(�2�l׶9��/����{^r]�US���/���>�R8M�N�f�司W�!�]櫜�6�o��|,�wՃ���tӃ��Fں������2]�?@.�4\��5����/��\�o<M�C�����GԔo�z�$��V"�C|��w��Uu�>���hD�ֺϿ��j�-3�����:�6�1\5��c��cV��#S�R�#o���X�ۆ��Y:�Յ�ds5����2�dh3��ո�)=��|O��g��H�cCZ� ���a,o�����������g����:���tגcpj����۠kА߱碉{n�Tt;��e��{�>lh���/6�u�X����o�!�����#�{��g�r�Չq�$�諅!��i�����2|5�q�}�![.��G�#���ջ���~BIy����^Å�U���׈��{B=�J�{� �����������3~��n,u?���������a������\i�؇e/����n�
���)�i�����"_��=��y����h�j����Յ������֜�b����͇�L����U��;�X��b��A�'�	}������ض��:�x5�l�d;��sS���r��d5c�w�)�9�    ���nR��ν�Ņ���;���-�$!4�;��x�M��\��-+H�g(e)=A�p��^c�����~�� ����1�8C��Eg��Y(5r¿
f�	Up��C�;��|�2������(P@�ˣ~,�(�p��Z�>~Ӓks ����o$v�8���:���>�ǚ��SϦ�H�%����6�v\��K�j�IE|�W���M�{\�$������;UM��NZ�����lG�&}Z3'L�ǧ��jA��k}~%�3I����o��iGOTf�3���<>�;V*fJzB�,&^�?�Oy��i��T�����s~P�u<fmv��L�y4��ֿ�>�)M�i_�,��@2��Ks[��k+6�x��C.B}������S���*�נ�9�Ŀ��U������ߡ���t��S��i�]�CQ��X%aq��|��t�6�ɲ�_G��ګ�\η�ur���� ��cY��ܦ���}<��>���vh���f�'����p��S�;�>�i�)>�-�b�}�1˕\�*N�I߉7̿D������V<U�~/9��'�w2��'5�7y��c�7f���Z�Ƣ�	zŮ�)j�Ǻ6G�U()�~�$�W�3>���)��yk�oM��2x�G�:|(�5�������L)@�Nc0� �����I��r�:��.��֠Ű�;u���SL��w��z�d���_"���C�<:��+6��.�� a���} �H>��4K�D��|U�k���4����B���OJ��S��2��W���Cӌ7yw�|3�������6\u�X��#ă�{�Iuڦ��r�A��9��4���|���6�M�p@�4!���&<<�y=?��$�q���9����+��[����?.R'�*�ǐ��C/C��@�õ��͌�^},S&����=6X�g���-:=�Ds�5����|ƛ�c�@����"��N�	�<�X/뮵��q6t��c�E:t=�t��;��a�\jB��~�(̑���`7���NCpys(��k�`7�aԃ�� \"����8 ֔��?�b��7���Gt ������ԪWÏ����d<�i�b�?a�8V�x,7X�ʤ̚ĝ��%���\h�|a��53�]���M岷�}�퉨�W�#N�q�Aܮ��&������QFU�l�=��>�!j#�����]���l��sސ�=ܯG�݈ ;�f����+}���������C�����"z��,
��`i��tQ�
l?U�$V�(r��|���G/#��e�ykJ%�q��K��R�j�@J�4�^'��SM��b�2D������Cy�;�n��;��Ʒ�Y���W��	�q��-9����X�tT��UJ�q�b���WS��]�+Dj��y�p.���a?F���/�[\�c����c��g�u:�Y>�+)��z�N���2I��ǟ������Q��BQ�'19�'}��i ����z�%G��Y���l0{)[�o���<g��7.@�g�N���#������T.����3&����蝝��#LV(z�ۧ��U�����o�W�-���Oތ)���C��+*k
�\������F�/r�-��qC�!v���#�����hAs�r�*�o�}��ly����wR��6C!Xs@��3�/�c��=
0�Z�	�h=τ��(�P����?�B��,!����09j�1�\|�( kJz�E�r�(�*yǠ�9>�m��P^�v�Q2�<>�Wi���"�_�f���G#����\��V��~59v A���j�DˤX��(�j�6�)VQ���<��Cq}�=��^��������j�@U���w�"�]�j.3�;<����	�G���]���w������j�>
�.[���h��=kE=���gŇ�^j}PDL�5_���y�Y���]��߶=�^�^��g���l�iV>������>�O�n|Ն��#�e�|�w�t�ک3�)��"�g>�x<:�+�v�,�X>�� ��_J��d'�r���g�-"<z���^*,"����������4)���S|���K�BC�~�4F\D��|�:\,�?
��X,������0{�˭I��*�����C�*l@K�B~(����c��9�vS��#O\��GQX�nN���K7���\'y\����W|�O��R����7�r������7TH���C�i�GQXk�1p@5/��Y�^��"�UQ/]9�\C��R���<�����q�e�7Vq�����MUV�IV%��7V��8�o����]������T	*.�y�t��Ҵo-��S	���Ư���C��t���rn�b�1N/�aM�P��_8�\��p�⍵|,�wv�~�	�}�����ںd�S��z�f�|��b�T��L������~|(҆:~__�iq�	7o��cQ��C��g�B&��"��P�v������/���7T����_N%O���*�>ͧ|�.{�3[����j�7�O�nvp��j
���㓾���-�ڵ2"P&t��4���VР�����o���@һr�H8f��(.I�e^�B�ۜ�9����Q����ҍ�G�+^�*>w� F&��V���[��b�C��V�����o�[F}��P8���s���-��(k�4D������7��ȱ���4��$�ؾ������F�4$�nj�a����<��.gJ���KH�����N����h��~�Vo��'�5
�K�NӖ��V�[I�Xl!o��tY��RV��+Q�X3H�{K�.��]L^jc͍�ƃX�s.R�Ï+AgL��$3��	�`,b-�c������}(�ƚc�r�l����߮�U��Q��f��|�N�O�},r�
T�h����@�b˸�+�/E�@�e'��9�Y�]�x��E���~���)ߩ�ձ�Y��fv�O��c�F�*�f���7�>ㇱ>0�RK�~u
�/��}I���T^�G�J��H��e��C�R�!��N�.�"��:=�cbD����y��3�$'�K[�,��`3��2�WL$'>�5{;�:����X��W�Ě4BLT�B0-��S Im�5X'v`�ݡ�@b-�[ܣ.�B?�UH y#��� �2� �&*�5a,�+�n����5L��3�ӿ�b�ZvWϕ�M���S��r\i.�eosi!s±�*�E�.W)���[<�����{�bU�4����m����P�M���'F �}�ǧ�]Q���{�١������&]鶜������E�R��q�R�C5���
5��#�o���r^�������S�I��H�`[x�ֹ�,&c����屑ל|wsC��7�򡸐i�v���JS����C���L]iW�5w: v�}L^� ЮĐ�T���	�o��	�G�q��8 vSYD8��a�]�
cU�sk�����cR�으����A�&E�ΆdF� X���0Y�"/�:�%I� ��?�$I���v:��O2���WP	��F���Ļro��b��4��M���X�O�}(⏍�[պ�d6dIz|�E������u�Д�q]��~�j@�����d�:A()���)xܫo�&�Q:eaXv���*hU�&�#7K��0�jq ��Ea3׹ݚ�g��zcu˖�p���8�d[������z��Shh�KX+����_��}Xsk��H�X�8��j�0`y\�=e�ZK����f�"��m���X�X��BoSњ���k󉆄t�8��45l(�L)E�N���8����xG���wj������QOXH�n�s��P>�m�sW�#���(�Z�W$ ��lم�8O~5qj��!N���7YQ��*��@�����QT�^E�+�ʒZ����+m:`r�����1kQ赒;�6�W���La0���^�����u�iJdX�������!���Hzo�Zy�FD��,���ڰ?�b���P5�a��b/���˧<6�(Z߼�R�'�`�>�M;�����@ʔȒ׺���8i���J"�ZK�9o�7~jek�3�څ�R    }ڛ$a��`��&�J��s~��˱_ҽ?�4�(�j����46�uA�ޟ8Qx5�B�BO��<9.|�����	�ßo�p(׾���o��+t�Hg����+��|��C5>-xO��͝�C򴆏�Q�u4EM6x�_�Zy5�z`���;W��d]�U�Et��S�UB��Z����r^n�Ӱ�GujQ��T6��vM:2�T�}-�g��/�ޚ�c=6�|�O��=�
���C��S����Bg#�ܲ.�N�Ox�/7hIC�Kە���$�f|���������  g��+
5\(�z���l鄯{\�(��uY���^�8�����Z>V�W�N�'^/xcm)0E�nu�o�b��Zx��"��,�ȭ��'�(�j�q�G����#��^k�b������'�$�⮕�C��$\�.�Ŝ���+bm�,zw;[&����F>��r'^$����TصrCDʉC�
*i
1_v����P�5Ŏ��?Cy*��!�i%H�*Su��I�㛁ڤ�]�����VR�+���䭷+;{Z
���<��	�=�3��u;^-V�.����]��&7���n_��r]ecd�(�ZI�B�7q|�§f8~��7V�:�����W��<�9�a��ŵ�֜�X>��W�C�G43M�;L��E[���M���1A�L��8�P������M��T��IoV������ֲ|�������̴d_�~�$�`��K����2���}����\��ٗ�y�lX���I�j��; �V�*jY�G:ƽ'SG�,�(��	��;-���a��~�Yo���1D��Vı��A�k���e-�lP��к�+,!����>�&�@}]zh6��6�X��̽5�pC�\9�����Z,�Uڀ���_C���o��?������tUZ���]��I%�~�r��O���o,�y���GZSG�Q��R�Wo;�����H�k��ǲ�}T���)h���G-ӊU
FT�љ
.V7�1� ��p��K���KY��c�[�3Pa"vR�1��E ����y��������� �ܾ'���eI(�B�d,@�X�����f�Cn�TʪhLK[f��;v2xc��ǿ�گ"��%;��O��Mm��Æ�W�����I�k'1I���Ʌ�|�w�֘ ��&=���I���P,�v�`{��U$u��I?���*��RO�ɭV<>����㢞6��9}��I?�&�<��D>�z����	�Ҍ�o���sW|Dԧ�X�֦����d�p[�K��� _�K�-�#�W!3G!�j���a[;�?����F��#�Tn<��zN��Sȡ�<f�W	���W7��"��wI$Ρ�ޠ*��М�E�*�v�dGz�&���X�k'Y~D�͇�P��-�c��M�2~�c��_��xS7� .�Rb�z���X>�UT�tظ7��@����)ߨ}
�#�yS����Z|�w�z�������B([_e�bm���M����$�tM�\2@��91�M�E���U8��(����I�?;^ײ},�Ӳ�ϵ!�(ă��6�m_�"�Ee��Z�O���X���l�q����B���P�atՅ����d}cU�F�p�T�Ӕ����q�E�I�[Ī~j]1�*���l�-	��2�w��P�:|,��+�O���O�@@�g}�g��L�H��=�3Mn��Ù��O{��Q {�>�;���qn��^���ַ�P]`{�3g��d��6��(�?��*u�ڬ�jS��yc`�_\?U��1(_�O�az[:O"I0�l�����`[߰>�|ë�g�s���Q����ĒF2��:��P����ף����$C�.�	 �{t}��V|���c�G�[�ԓ����Q�m�X�4~��7�;6�'|,ʝ��7�%�)��Z��͍exGY}r���R{q�աB�h\�B�����P����c��+ �.�Mo��a�g�oܳc�����i�ȵ
��Y&��}�c���s]b�f(7V��#bA7l~Ƞ)�OhR�t������aڠp���'�^SuPY��t=�ט�Pl�����pusMˑQ|���i���e|c^y�o,�! 'Y���j�`-����w�<�d�*�%��v�
	�ǭ�M�O|F��bջ@.{V&ƅo����Ed�G�z�5��|(��V�5M��*���j�P���#1C�?�۸<>��z�D�ް%��}��7�y�-~.��hv���nb�5ė7j�M����9�i�ډ0����yzE�|΃�b���s�=��s��6���ѵ<}��$_QS����<�>���������U�
�Ͽ_q�a���-��jlq�ϣo'+������N�%e�r�"���q�Ȫ�u�e\�"Y��e� ���?����O���X~)�V�f���S���}(���������S,^�s��X�г�YYJ8 ur�Q��bhme{>*���B�=%L-f~����-�PFN+�3�&��ݿ|�C-7#���zs�^g��[�O{1)���MV��bq�Z���ks3 Q������[�>�;g7oJ�éǘ�e�m��F����Hm㺲�q��7����wu�Z�ë�}�C�y��cD^����>�Ǳw|�sg���[u�6Q���Ԣ�j��O���*xߓ��͈���d��H�/ �"�
�%5�P��]���ɬGG�Z��<�r���^-��Q��p�%?ο��w��#A�P'�2�C�ɦޜT%A�I.�.lT|)]�� w,>��j;9�Ȣ�v�����G�P�k�Z��$�9����Ģz|�_bD%N��bRw������e�ݭR�"��e?� 
�"�;��eR�8�t_�b� SH)L�Q���᧶?��Ø�5�������!@��}[�~���gl@��ڿ���Sd��^Kl��PՇ��D*k�ޱG����ƨ݋A�R)|������kw.s�Rv,�5|,~&M���uR26|���s��[�+�e]��Rl�Oy��ﰟ��;�����3���c�_�����j�O�Nb�Bۗ�E��1be+>ݻ9|²�;;�x�ՊOw{i;�d�d����gU|�6���O:}�V��E+>�����ڒ�X�)�������e��dqaSJ1�D��9����'wap�(�r*�d�Rna�L��'���˅�1�]�*h��=t�)��Q�a��$�ƈg���];v�	zJ�7c�E�ˡ���^���Cj$vH�9����ːCٶ�3�x�9��
�j���0���Kj>=t�B|���}�q��4��q��ECW���T�)xj���'��߱�P=V�m���}C���
K"P&��;�J"a�6�]�sUQbL�)vZHsF���_��cR�$�u\,���凓/��y<!i��rMMRh �wՈ��F�K���*�A�_qI�2	���� }gлN�@;�5eS ��=o�?pLT��'�bk>��"m��:�L�h!����8�Na_�Ƹ�)��C-�E� h��:����_g������
���>�8	��C�� pF�N��N29�C-$���.n�N���֦�9�P/D��+��I�-M!T�y_���Lm�:!Vh��r=�$,���\����Q����O��h+��i
��u+����s�b�MnN'��б���OE���w�y�"���)�D��[�՘����u#�ۮpuR�*K�."���|ұ�'�~��bUCa��U9�'_{�6�b-�vJ��-���hl!�o͈�ޗ���<�)��En��#�js�x��-��R��<�v�0�\>�n���Z~��ݤ�c��t�z?).�9I�˧�0�%\��w\�
��`P��� ̼����oS@�?3��*�k���;�c��4����(?� ���iR5�?=�!1P�m��h,��1���伵�FS4���y���u���e�<M���~��]�����Պ�^;,���+�{#�'��<��b�a��Ї��e����L�X3G@����Z��Ce��o,My:@j`����Jc���=�?�b�v𛂱��C�+��o8�)K��	ۓ    ���sih��R,E�},��_x��,B��U}(��/rt~��ʘa���_K�����=-6ı�AS$?y�b9�T�t0���dV ����Љ���Ӛ.�0��9�z��U ��)?�}��(���L?��)L�),�'p܋��f�}Ώ���oÍ��L^kbQ�QH�S����XٲaS �b�)�@A�"�[�<{b˸���9?��aㅤSW�0cv��Go3�0V��6�	����N�)8Ƿ��hٴ���ȉ�R�/iZ�X�`������B��oRD8��������?���#|\ۇ�6�N�)�e	q|(r���uE��n�q|Σ��'�S�]\��Ϯ�s���ޫ�Q
�ot�|��s�Y��Y�+�'�C����8�19��2�X2��v|�c�����urɓI�}�wVh� ���4WKֱ���w�tӃJ00��OxS�|�}|�B�laԬ�9>�͘���/~���*�#om��Bh��� �0���������-�ҁ/�]x��'g�|W�20,Jz��߳=��(,"q/�n�����IH�]aXsH��z�h�Y�&PX�w�aˏ��!.�w�I<���+k&)��{��u�����c��@M����IW 	�.��+����2�t')n� ���9��'5Ǯ��9w��%��Hzn�C#���佃����4z�ҋOx�7��Wfw\�ʸ1�ŧ��2��R�Y�-�;�չ^|�����>|��V�;��u�,:U"��Do��\]��BVX���0#�����fL����s,��(�l>�UM�r�8�q��.�Z��j������b���M��;>��F�X�[�`᫶~[����"���U"l+�o��`r,���E�ac��~�t\�+�Pt1oH�Q�4�y��b�[ͼo�<�e����hQ7ۍ�8k�N�VvY,�����Ð��d��_��y���<O��s��Pk�X�W������}!��^��v�>�I}�C��\��������|m�[{k+��G�|��R��`��]}餸i>��ϱ�<�? %/)o�O����ηt<.��K��4��[��yo��I�^Li���,��0�Ѡ�f�_��%�~��G��j�!X���sP`|�rg�-�5K�������6'7IFl�H��ϰ�l<	��;v����F\!U���q(��9�8�G���>�@w(,��o�� ,+B+��&�U+��a9SF�?T[�փF:c���ZN���J���}�ʘrE|�9�N����������U��j�c�e���V���"y�I�X
f��7��\)I
8�Ēg��k��!�ijҗ9$�� ��#���P�*:$�m����P�U3�wFOf@��%	܆q�y��^>Ww0�H����.��M����a�n�=������Ca���Z��;������g<*��!C����%�x�߇�xs��"J�5�ؘ)؇O�FU΂�)�T��I�?�X,g��6�/�(�Rw�t�QO��x�Ez�wN�� �ؙ�O����A�>}��	��������^����5�� ���SNxd+x]!X�LC�ҌE��Pm��������W��w�&(��b�u1���E7��̘�a��b㬢j�n��WI��,F��u�싊LZ�}��c`)��m-I	��<���6�v*g]wQ7��(���4��G���W,5U\(3�l����f�֝I�|�7�1&K��y.�,�d5L���=�,[���'�m�4\�_�|�,��~�|j�#k�>}���|��T�}��B��'$���I?h+\'|B<0���S���$���*3�´�W֔�q�OHE<���k2<P֜����<.V�Y=�(l�y�[md~�����q��
��8
�3����ɥ ,]�XY��]���x��P�;��^�����<ɍ&~��c�:5+.��J�ͤ�W�B!�C��q~g��f|�y�ܠ_IuZ��Ӯ��TI0�k�
��7E���V֬6�O�ze�����R��Z,�Y�����Xt�`+i��Z�G�ҕ�8P�[�l%�B�jĶܳGΊ�V���Vӧm�H�R.y���$��_����ɪ�b���:©�1�:x&%�°x��=a������a�1�(�ID���T;	�+[������9�9&��a�dM0_β�S�l1}(k�,P)����ߐ��ɵ8���l��d��C������a+>�9��@��C��4���="8e�ܮ"_LLM�����UL��?�%h�P�LS�X��?����P�:��1����7]M>�r��]����ѳ�-���°�Wl����ȊX3����z�c;k��SA>����g���5H�7�}�"=��F�i�Y����M�X��˛Q|�w��w�e�Ȕ�G�Y?���s5�յ��Q|��I��ڙ�W����g=$0�Y` o)R!�U��pKG��K`~���=Ɉ�BZa��ɒ��1y��p_�]�&u�M�/.�g�e�8�6�V��WQ����2������C�L�q&FjC;Bs.y�mx��z.�!�T}$��c8�Ҥ1gr��7�N�0��ǥ����4��{�j����SO��/����_^��J�S�/W�t�P����q���ī��:�bQ��&��	�R���w�n��ke�"iR#�bH<���X&x
����Zʎ�_QM׮#~*�]�$�T�P0=�N���\�����C��ɵ
;X4��P@�0�œ�*���j�ǢA���P�D��
F>�1L��x�����-�h>��X�C��8�;.|]}�{r5o7x�:];3����s~P6�P�uI�uO�$#|�>�Nj����l��XNe��"X�P^i�^_��BT��u�00�o��WR�bs����P\�y�{*E��$�zs��y�*6=�
"m1z�����p�l�7C�g,@�;��>�Mg�L]���e_�>��~sI�e�/Y>,ʔ��#��m+�_�"*���P澍ĺ��<�[\O��c�k���/����'����|?��<�F*O����W>�G�k��g�%��k�����Мg���(�~��Vٔl����P<P�������2��&�Evo;e�(�n���k�1|,BR���5��6Ij��#��K'\��q8������j��g]��0����96�GV�M���d-}(�bA�4*Q7a�3*Cd�'��A
�+U��&S������$��t���ʈך��9_�Ϥ*���nN��b���<�����73�	C���4��f�6��/��S��Z=DJ�������s�����׵O4�����������LCϝ��0�w��"���rGfx�]���i�LQ���Y$��z\�j��okCF��ء�+��P/����l''8^`��0n�bF�X���6j9����X!hP.��Wä',����X���G�����Fk�X�@㮁�@^�I��C�q@�rh�na2�Z>�_50Φ�2�ۓ����;���;Q�hmj�0V��,����M�ubB$S��3�s�:���չ��Z���%���ˎ9?��s~��9F��i�ߟE�4��6P�����ȧ��cU���\�����H��=|(���B�����oϿ�0F*�A7�����2��,]����Ƭ2d�W�+9��v���~&����1���c��f%5S�S��%�p�Y>���*���m'|�q��e��`"����wa��cQ�t������՗�l�n���O�[WS�-YF���C����=�<1Mm�� i���m

)(Iu|�w������%c�e��Y3�م�M+��m�$���aJ�l7���m,3��@,.��A�E1�u��v:�6��*/��@*���J�O�H~����jB�����u0��О��~M.b�m:���b���7�&��,2ϧ�P��zL��=/��0��B�M�F��߂2^���t�@wC�ąa=��;"�)�ۂ(�O�s��2�ޘ�f���B�"A��Tg>��j��0���Rx
?K���c����]����X���N����+�}��N2����    X��5q�|��^�~�,�Ū$����ˉ�'��
R�)A������;c��c�7�vܦK�č������(6��w��+�A��rh����v�_���j���0%*�f����A}e,[}��*�L�S����oK���#�o�Z͙Rd<�|ݜ����4�����J���y��oOj=Y�,��_;|lYG$�L*����B?6Ҟ��K��˦`�����8P�C��Sy뽺�-�ӛ0���(��_7W���r��<�$~.��`�c'G��C�l�0���K�����H��H���3�sϨ\�N*����|�w~�:�7�YD��I�g�0�S�8%��=3lf��mS�?�����|Əqo2��U��a��_������f-~��b�YU� m3�|�G�`�W��Y͙n�g�I(����Q�	/�H&��G�`)�� n��L`�L��� XR��+l���gM����u�+�ɐqhՕ/j�u,<2�j�d���[Q�M��H�]�Z���<勀���*�S���+�T�k	���*k̛���<H��]��W����������I���I�[�cp������0s����.ӱ;��O�_��*a��[GS�!��~���}�g�U�U��ȮW_�����4�J� sr�(�z��i�X�F��&K�W�>�* z�~ea�!�¯l�x���$]٤fBz�(��X��(�������!�9�T������U�8��bp*�J����F'���iO�=4�P`�b�Tt�_����o��{�� '*�o�S�C2hAi�Y=i��S~�w$��kq߰g�s��c^A�
�|�����3}�{Z�^�
"۠��g<��KV�*�<�#�Ys��+g����<�MlO�
�"Y&���_���)��+b�n�^U�8�g������|�$>w�V���
��X(ߛTdF��O
T`-2h�����-��B�� �����w�x��;*[�[T@_��Z�⚊�Z�$�����l�=>Q���80�Q��7�
�O��̮�z�ӝǞ�\>�G5�Y�Y��J������i?8�~O	g�֯�g<����Ӱ@�Uf��?y1���8�um�2&AO������W�����;�i���r		��=�ʗ�����N�a�L��B��l���I��8,���_�I�^��H&�
ĚD�r�_1�Ɇ&��������c���$��&�o��:�ԫY��5ED���w7�!&y��Ozs�n03��wˤ�+{���;
��*�<��x��7l.�	Bx��*�T�
Ś���~兯dlZ�(��g�������O�6~�
����BmU
w���X�yI�*ר<:�`q+�L�bK��`��h��9�|:#���Y�I��i�f�B��]"�ۚ=��ngD�y9����Ё^��C�!S!?i:�!��H�"�*\������Z���AQ�rޜ���f=>�[��;D���p&���z|ʛ8Q�\������z|�7���Ll���X���F��� M����L?���aX�C�췛@hƮǧ�0�u����R��m%����s~�+$��rW�cb=>�Q�uS��l�"���&��S�,eؖ�0�[L�]
ƚ�	�:��U���ṼH
�Z��9v_��l:���Ϟ�a + ^�[��B����l����iU
�eSԥP,U<%1,������X�̇��8|�J���>��C6�φM�xoX�w�K�X3��'t-[w�%�|(C-l��}�&#K�X�:4%��bQЦ�X�#V�)��<'J'y/�֒
uU��ҍΰ�V�V���Ԫ>�]�߼Bc��A��@rU�� N��7���^�?b�)?(F����$��m��o�S~ؼr��Oy|�2ݗ�P,����1l�6�BV٧�>���g�
��-�[��Z,�"�ݢT_��!Uk�X7�����K��v���r�W���j}�b)����Z�42���|޿��,iw��~���'���cU���gQ�eN`K�X�|DՌ]T�hW�;.��B�e\��"_u�L6"~��x̦h��H!X� y�\ͧ<�����i�ʆ�[I�7����{�B�JǨv�$O˧�a���8�~zG��j>��mU��5ƣ���V�	?�xR���%W�;9I�C�!��%���唛�$=cV�R���z�p�ړ�X�V�R��ꌔ�O֙`v{��MaXN5MF�t�� ��w��-d{����G�,�Y��Z��o������|j�O�|(��0���D��С�����a�.�)��W\���DXl?Z=J�ͬt8�$Y���w~��S~�����*]>�uE�M=|�w�.�|���3��_��S�VżYU9�����S���M�<N�X�ZR|#��FP��+�d�J�wq�9|ʏex'�4\�I6����^-(�hפ�>�=�����hヒJNU�~}�������#���P���أP�%"��
���=����r@,��Q.�M|��ոM�o�2H;�#H٠C�R�!�F�AՆ���������rH,��8���|�˱Mk�X��0~�.�L���{��t��j��r��YSR�N����fރ軛���6srJL��w������o㪼&#���u�-S~�~*U��[k������I��۶|�)����a�!�F�����o�|�c������5��Y��w����ƿ�j^5���up9 v�-��1�9Z8[�����T�}��ws�4F�jp��n��X�A1��-;��^Up6���,O��a7�E,����[{Kh�ᰛ���TcMumH�ć��a�Qa������{�nz�Am� �ri���u@��k4���T��tR[n�� FH
�[g�&���߶O��УJ@u{��d�`m��`�����(3���ӾOn&�X��xA�J��(�O��LK��/��ie�	�~m��&�Vp_�R_�Fl���>�;�i:q~�o��)z��Ӿ�q��%�7Q�vT2ӓu|���-8 ���X{�+���@���{H�"1�����u|�c=&������am�|,��0�B��d�M��4I��|��̨��S�}U�X���������I���:�PG�j��-����8�y��}C Oj�=���r8,]C+�ݣ�]�SG���!��<��O��RTj;$�N?���v���VYƈ�vH칌���%gW��;����se1P/Uf��\"P��U����tɦp�'�"��a	ұ���"A����^������5US����oFz�8Sԏ�4^���~|�7��b7��~pUx>���;�W\�Nj\Y��C����T���?���\���}pi���h�Y��z<����;Rz��%_T����W[A�멳���%��>���s+{��1��� 5�c|���V�<�������}���)
5}(�ET��G@s&�ً[1X�鰽�\��V������ ���H��/G��HLV�
���j����Wz�fs፸���J�]w���j��*>�tj��55��I��C�pa��F��7���vW��e^��s�_9yqW��%9�}������]}ʣ��ƃ�rռ�����s�t�������*>O�O�A�C�����6����Wi��މ(N���V֜M�P��R���cj�V�R'��\��a��*�X��V���u��ށt��ڊ��r�S<F��4o�')t����a�:( ��⾣�X*g+
[mc�,���44왁�V���,���H��ɕ�yo�a�n��O�΢��M�&���/�W�~s��r�Ψ�H�V����jN�I��r���V�`:��g�����o�8��c.���&�õ�؝g+[�uu�>F�<E���+*�'�1^�[�[�QV?.��5�C̺��d!��8nEb�b�L��r�����>~,��5U�A��K.�bk��k,l��3Nr%��s���R�f�q�'ۭ��'��t�QQ����̾�&=y_%Q[����5g�޶B��w�ԙ�i(d�[�X��A�X(<_ܓ�>aQ��c�ʔ��˫�q^�(V󱨕C5E�e/cIdC�b��x��    ��%UM0y\��u�jIUF�D���F�XĢP}��'�Gj���a��c3�Mpj۩tp��^/#�ִ=Q�!':�r����:��y���T���Io$��m٦0��(kO���t�1e)��������>�;/���ˍ�S�d���I�I�P�=�g^	AiOi	��s8��yue��l��#h$�HCL��T�o��C�W�d��ؖI�m�\ ���6�2��)�0� Kb��=��Zb!���l6	��9>Lv3��M�c�ʲ���[�1�d�V{�3p6�n�5���:[%��!����<���? e��Ws�:��Z����k�xο�O�N�����%�!�(����������c����z�=Ƴ���p/��#>k�Z�P������.#�9��b�Ñ�
�a�s#+.a�u\(�/TYy�4'�l�l���X��<%� '$�f��]|�I�����+�c�{׿�������eN�1)o��=�D��ݪ�� dg�'{w
�l���o�;�rqʻ�qṇ���Y�B��ۤR{��7���xkt��ug-��9uybߣ�;}�A��x�}��m��О�J����>�ޣ�.����yqf�x�7����)G�`��X������,�:�O������;d�)�4-?A����Mo�mt[(��`��=g뽖�=Ç"��w<���m��!���3],{w��F�x�l��L��&3C�Y>�3W��DyYa?�(��훘�Άx��X�d|�P��U�>�y|�C���~G���������G��Q0E�}�����)i�`�4�0�8�_����������ϙ�d���)��E������f�����)?��5$J�i�}FI����Mc�4���d�+I�����|�7�x�C?����Cg����X��8��<�G26�CQ�W�;�j��6{�(X��ʈ�u�)�G��HA���hl��3���)�o,k��W���a��u�/�����E\	����cѩ���Ӝ~s�t��������Rr�d\�9�h�w�U`Jc]�{��;YM���|���d���������~:Y��+rB��̑N9.%���N�f�^%�s��Y�6�y@�غ�&���P6*oP}]�O�a�Cu:bu�5E�����)w. ����4�w�?� \��^�-��?��^���U�ܾ�J�DO�	�����Z�!/q�V��3[�@�G+���]\>T���h�pY(��\}��>�'|��e��^krS�v]I�X�'�:D�E���ݓ�=N�?�+ 09�t#�+y�ͧ���\/p��ڋ1"�O�a"Z�5]�y�U�
��&��\��`��qe�\���Cj��X1[�|\�xt��19���"i�ϟ�H|B��b]��C!T9N륞�_q�P��I�+O���vN;>�WW�X�y��(�j���|&�wG��J�^|(�d$���'fr��|�W���~M�sk�X���14�$��H-㧤����	��k�� �䊳��}�w&jǜ�5֤�f5W�I?]�&�W�`5^�=
�ܣ�Hؚ�7�IO�o��%,���{^&��:>ϛ��׮n�������T��I�j�+��:�mFq��ezH�i��'/Ш>W%v"�?"���J'�h.T��Vai���do�@��X�f�]mJ'��@�gʖ����@'�%�|���1%e˭R�gw��9?XV��MW��l/YY9|���؛0��5��34��0�Ǵ��ۖƄ�3�D>4Q4}����鳸P���%�x2�xl�.>RU���ܐ&gmž�cx������8v�]Q3[�� X��s���J�h�;Y�:�e,\հ�@4�����Wn΀���m|g����5��_y!�hƴ��?��(����|C�u��T�>�MA�@X�P`I��S~�q��dt�<Q�D��,���H>h���!b/���s�D�*8�C��-���z����}[�g6m���p���3�}?3Og����c�w
+�w}��w,Ő���f�I�U���S���miқGB�\�3�$�;����d\�;v�2���R����!�0X�h�L��
0�b��� X�*��:�����s7~�OU}(�4#.4��ӈ�S��X}��V�+>�z��>�9b����z��c���ڍB���
��m�L���}�� ��;���Cs�l��^sePr�'O80��s~Pղ��1�,�z��s���4lqu/�1�T�*:��[`Ώ�Yz�b�A|�;�������3�:��H�<u(칆gf�b���^���r(,�%�Y`���7�֘�{
ˁ
Γ�gyA=!8�K�ڢ"���ÙP������{
���$ܿ(>"�j��0����-���eE|�
keg~2�w����a�2�+2��j-�y|����7���=l��o$���`�s'�߷zp~��o,���r�bV��#�F덥{=F\,�&AOWf~�o��#u6�X�(��a+?�7.V�Q0a$��1C��3T�qB����4��L�����it뿑���*���w�7I1L8�o��cuޠTF��B~mh�����;��8{�[�Ƣ\o��b5��{�Bm���I��'5l��\4��Ͼ����;��UA��a���I�g0����=9��j4o,���^�������?�'�`�Ԡ|1�ÓN����ڣ8,��, �"��}�)B) �6i�bqA�����dX��7�������ufZ����(k�F4�ޛzi(�NB��U|(��BQu�*s�{#Uiѣۘ}J}jJ���|,�/i�<�**V�����X&QP09i_P�����7�p��D�)�a=��m��T�X�x���Ӹ����H�\�X>��J;��ڑ��j�&�|Λ��jM^�o5<
�S~p���觚?#� T�)?l�`4���(�?��7�����S`A�8Etr���i>���6(�ooЉ؜�;j����ZE���+�Ex{���
% �'u��Zm�
���:!n��Պ���SH���tJ|��r⽱���!�d*&1%^t{c���0h'}FK%Q��:.T��.���c.�+�p�����gwF������5Xv����=�6�Q��c�lTw��A����峾o
}�f��&Wl�I��?����Ɠ���'}�X���{\ɠ��}֛�%���`�^�'�iO�Iom�ϋ��t8�E��H>�!F9`��?%}�i���9?�
��ߣ�El�bM�!p��8��J.�Ǳ��e�P��~�q���*S�.�Ȩ��ι.��J���X�ᕦ�W6�,�aنso�0M�M�8\�m��w*��G�y*�0�m�-��d��r#���;�ùPT~*����cO+��}cm�G�8�I��Fur�(
[hl�gK:��
�T��?}�wV��Y�Rg���\˧��v4�n��ʌ�o,���W�X���[5���3~�mt�����g1�[ӧ��W'�a�iٝ��)?$4�����k6=�b��&����/:/�+ˈ?��\�xی�g>�9\K���
J�F��z�JC8�|cy�bԎc�P�IqN([h�� ��Ƿ(�s�<�7Vq��su��{�Q��I|��X��*,Qat��9ȍ�p��=
Ě���3��NB�X��7Vw��n[:����Fȷm�s� �����G��ɚ&�^�6����S9C���k�X�:A���q�Ԙ.h>��b�mB����+a>��b�`�،���DI�P��=��R"���������1NU�b��XB̶K�WNe��P�X����k������s�\�[�l�n�M���:���>�0}��q�
P��7�p�̱����wi�+~.��Ơ�\�\:�8ׇ$�\>�q�B��K�뫞4ۧ=8)x{�}��n2D�>�q�C"��$u��q�P�X+c�������~6fqk�xl!��}"�c2��6x���±�m��]�
�f�±�6�`� S�f.����O���PH��0�돥����G@3��3H�X�    �`�����4��dG��\���թp�` ��_l�cMb�AN�_��zY�p���m�{*������(��z�/��7��� ��I�㳾��	ܴ��bZ�H���������L=$l0~.����B������j����.�]4��ϣ����X~��q�X��T�m�1�޳PӇ���ɒ�H�s�'��m�a������g�/{�L���PY��Q����uUnBbJ+�%!���A�S`Ô���p�캊t �,`ю���8V񱦱H�$:v��{�"m�a����1<&u�mK��A��z��	}��o3|�$���A.l�7���*����g�5��HwegIj9D�n*-.����Y8*)����k���|*fpHo���#�R�I]���t8.���MTߣf�j��.���������c��F�� ����������T�L��!�d�"`g�e�Z��<�?r�vY��^�v
����.�%��R����J.Ȓ$;8F}o�-��P�!Z��S�n�A�Sg�d���7���+pY���k�G'�r�)o<z�2%����Z�R}��n��H?~
�S+~X�=�A�@������Rqx,�|)�	�>�w̠���X����� ��!r?�Ccy��_d�ʇ;�-5�O�]�z���2�������e)��6@R��{��_q�PF�%i�����o#�����sU[�m�ܷ
��$��E�f�6�X��M@<$j���X%P�iu�P�2q�Y��sr��������i��>凕.p�h���Q��%�o,�����my��{��P��k��E]�;A�+���.�ٞ��#l�ؖ�%��p�X�X:�8���z�tЊb�We�}$9��&�:p�ۼ���u��� �{���%3�����j��d��_�IMc���}!stJjyEc+�o��+�2_�;�P��.xg���e�5R+
�V�].p��j
��ja�_���N!�	t������6>�������Ʋ�8��E.�{���tA?�p?��bɂa���6%�$Pܻ*[�]=-�S�M<�d���U���k������8Y�`�9.���k�q蹺�1թ(�����H�����f&�P��$`�Ԁ ��37$��iQ(�bᔩ85�@R��
�"V5 �CG��?�by��zl��&��q��|�ONh·mS�2>�O�fTօ��_K���S ݛ���ѧ�<fF�����m�y��z�?ɐ�L���Ѥyɦ�� /y��d.��4%)ob��>k+΁��C?8�����?��>��.�Y��1�������Px{��G�����e����w���0��,��k�X������%�(sC��ET���f��6�bB�Б����ȸWN?F�����r�/hEa��=m��v�bKg�
�"�"�S9�Pp�ڟ1�S�O�N�cÒ�#V�g�W�>�A~#��5���K ���'�a�[*�vݸ
�>�m��)�Z�ѓ8����g��'������?c�������Tmr8�'��Ҥ��eeɅG�2X�jn��k�XT~��0.Zs=�a
}��X��*�5N��w*7�?E�Rފb����a�@@Wcr���<.���|�Ǫ��HU���q=z����C�2*Kq;�lf9��I%g�b���?�ǩGW�f�a��c>��ޤ%3�?��yw1@��1���O^�+Hu<-:���'�ި^Ö�+�c�P/���}�Aڦ���@g�Xv�@tB�X�2���P:r�R���CY<�^J��h��� ȋ=�
�����k�~=ly�~`�d��CU�2���Y�Å��Cy-�F��N2i%$�n�I->�bi��Uש�W>��i��)�7!��z&������xh��R�}�[l�{������]�X��:k�w�9�3T5P�WaC<�=�=b�\��C�?���a�^��o�"Kzt*'u�8��ߌ�Rt��Z�/V�>V�UJT�������$�B͋י/�M�������ůj�N�z���;�z r�4�0�c��0$G�ڪ>�mg-�Ǣ�*G���k�Fo�r�tq�>ԚR�r����l������(���� ^E��̂2q��`aӹ�WRϓG_}�w�����X:�4��8��Oz;�0���߸�ɹU}Ώ�^�^��ѫ�!�:NԪIO%p*����ޗ\Z,3��}cu�в��a�'����z6����e�BPj�j����0j�>�&%����g4�����BJ` :�����6DM�k�Xx���6�B�V��4c��I�{�����Ǵ���{)�̑b�����crR�Q���V�d�Q��5����=��>��`��S�>,��v���<�p�Z�Oyӕh���u>[+�:��|ʃ�QUl��U���|C���m�U�(Ic�B�7�	�I��X�����3QH��'�m��i��?�$I}�c��1�H�jB�X������pL%���7��l$�[�>��/(�����,*bx_ԇ�o� �����o�3%N·�Ioo�79Ʊ��D�儇/���S^��|���X$s<�z^�6����Nꏧ��MK�V?wF~��C����7Q�Y9��j�ca�
�����H$��wv{Cq�e�J,�Vw����%�⾧�jS�m�c��:�U��}T�c0ۺ��j�f/�%�Qq��sL>���z��N�GR}���g<&\��E�L%����s�)N]�����6��X`W������~�<a�����P_s�h�}Iz����u���Yo�����Y?8]� �'�a�2��X�lj,i]��|�:5�1�e��PV˷�5ۑ�
��H�[5�kI�y}�C1R��J�PѧE�+��8Y(\��������M>�p�hc�~�������O��xaF��EL�mN2S��r��*�k��--�����D-�-V��@�6>�m%�\la��ml��"e*^���\�z̾/ϖ�ە��t��ͪcn_���lhI�ƪ>��y`��[��wv�bUi�S
"
����L�Ę��.Z�?��￩`�Ů�cю�¾�}������&;��ov�/d��JYt�5,��q���N<����v�:�ʱ�Ӣ�CW���8����B�g�hz�d׫\녷��8���d�����E�~ �SʒR.ƪ.�5:�^N��_g�7V�x�5��f?hFz��bi��y��s<��E��7���ѿO�
70��O�kd��o��>���>��A�^>��5��w#�:��#I�fG��I��x\�}��o�O�=�|�\D�o�K̥2rL-��È�S~Л�ї���4���)x|����A�� ����0�c��ĭ;�N���u�d�RD���	��W4��dc��:$v�����[�:1m�G��7�e,t341�:+ޗ��Z>��!a~P4'���q�;(�Kv���_�����g���%��Wz^I}�&(N����)#Fo�7T�	c��t��!��+��j���7������9,���oь��8kyj�57�.^W���k�>d���x�����jN���;�]w���㓾�E��K��&}{|�#4:�Q�ͼwl�2��'��5PAl͇zw��H>�����}M�oT�#��b�U��A��H�ci0|��bm����y�'Q��1��90֖���
��?&(V�����X~bEWJA��v��Cc�G	�;6��Mg������4�3���;r/�5��X�I�j�#N�-F[sp,���ֶ�s��bh]Қ�c����i[�J�"���o�>v{ӽ��H�ׁ�X>�1	�H{���� 4^h��}%�i�.C�b�⬯>�MA�,0O�='�bǱ|���T����7��J��V}֛c�d�[��zqyӪ�z�ߨD���l�v=1%�U���عX���w��0Wsh��ᅅ�:D�����U4���bQ*hJE��t$������3`a�骛zuL�X���H#��u���x��{�^/�3�N6���S���XRD�,�A�w�>�gu��� �MCtИ[\+Qk��h����;�V��A%��]���^���˿��Њ�Lȴ)k� �X����>s�j�x|S    @��*�ݪ̈z��x���5��~��ڊ?n�6��M��t�/���������D=.����xۻ�'������O�,%��Q��2����{qR���6ᤷ��:�ll�g���g���hF�n*��x�>���oS\td��Pn�^
ɚ��+���d�Q\�������z,=�q��pdvC�V��X�e��D�/���J�ջed��/D�a;��4R#���v������1��n)Y䕓�|r�mbsB,&ͺ�d՝�N�pʹ��*_�z�?�#G6�d���`2�����K(��} ߷���q�a9Y��a�J�<;��5����d�3�A2�i�O��G�R��۸���;V�ʤ��?�(mo�j������[��Lƭ�J��{���'�<{3����d@�*-T�'�|��ɴzgU�%d!L�����9MS���Yaf�X������h�����ck�򱈥>�����#�4����J|��Nk�ۂ���ed����%[��eDr�:�$�,�4���b�c�v�����/w~P��B�����<G����x�R��� �|�J�������é���k�P�ޡa�)������ݻecUx	=ڂݦI=�P�ec+GI
��nU�Iq��[i�X�E����C	VN�j9�ұ��h�V*��9?�ōb��N��~�ZKqj#���c�8Ŭݪ縒���>�0]�l>�k.9���<�����MN�c{�_�c^���ƽag�۝	Uٗ�J�0'Y\��F_��ߠ�1��!��'��A?x6q}C��[��Jݒ�*<NUۅ��kԚ��z)/]6��Z�Gm
�@ٕa�Xm���c��a�1{,����R���ǩ:ׇk�H�D��X�c��zfs�-�
�e¯Տ5�d�/u��j,$h6�/�@m�3&Ok�X��pL�5�}%�bM�n�X�������T5~�գ�>��aņ6�MY2�����c�-�e[|:X&���WG5�^��>���e�X�QV��v<Ǖ8NxK�"֢f?�#ǐ�j���+��պ���$O�Tu-	5](.���+~�I���v��VNU��cH��R\(����a�J=(���Y���}�0��<�}������#I�pW��O��Ԡǽ�) )�؞� ����*�s��)�:�4>����3����R<��&	� 7Ŵ�k�1��?�_X-���0�����%tJ��td.q&��+�VL�,P����]-�c���v�J���5�\ԑ�f��꼇�X"V���gA�)�Qk��;Z&Սv�oH&��F���X&����l_1
��Ed�� ���b�W���p��X"�$>jT?��o.ׯbyX��Ɲx��_^H��u|'��aU�Z{�n	�m��Hؗ��ң�m,��-��r 3Kê�8uq���,0���j(4�1f�T�2��q�*�Q��v��A�m'5�X�:����r(�̅�%a�Z&1�lZUU6V�K�"e���a��[���.�$,O\���)�'\b9X��D��rsls6�7ēbI�[U.���|3�$ʦ=Œ�H�(B;�c�N�s�b9X�J��~Ko�ݹ�X�V,��H�t��ؾca��B��ß&I�_}�X�\,{Ca2�v���"3���X
Vc��[ӬyEV���2��]Դp㔭�@*d�b�q��k�sR�Aɚ?�"Ue������}IB{�BP��Z����(X�B�]��3����Q���9�D��_�UT��$��(X�4�1?��w�_	�xNP{�+�6����I���Q�|��i��;��Q �T��m�j-�s^{�r�Ï�|,jeV������D|�Z?��L�ne���C�DeR,۾R2B���Sa�G��U,����x}p»��BG�����+B}XĪ	[l��׾�_Yd,Q���kJ����cm
/�Ye�[��'�� ����*0�dQJ�՘�˾j(pl���[��b<�*�~�*$�vx�����O�`�W��W�x��VQߒ!�\��b�a�Z�!e�h��_o���W��ȭ�e��cyBd��܆��3�Ib�SK�6*ܰ �u6,��s������~nʽ��;꪿b�j �~�PfL�����|\�z����=�r�m�PӃ^��P��n�eM���l~z�c�ˊ�e,�M�����G)spz|���X�W� ސ˾�v�{�����k<�U˾굇�u��w�I��hv�|�T�v�B[\}d��_U^��b���j	L-��+���s��W��Pۅ�n�~̮P�I� �ү*�ʒ`/{�ӌ��dVJ~��Oz6�����K��,��ۺ�S������;������گ�U��'"������<�f����{�������n�}�����+��FO6k�7G��-X���O�!�S���5L$J�����~���V�/C���1T���<�OŝW2+k�X�vl���:nV���k����m?}2����I~���X�q��<��{�$O~�%]O�?��x(��H���Xl�uH��٫�;�Cҁ���X����L38��6�]�c��X�9�|�u���t���T	��-��>��f1R��|S���������m1��ٲ=�τC�~E�"11����չ߮:����E�:xۃ�3�����F~ߟ��4����u9����g�X��X�c^�$z�i:ϋ-\���_���%������>zN�I��%��X$��.�*�'��U���:�[�������5����1/d�h��7+K@ e.uw<�]���2�N�΅���v�z�����HE��l�P��iͲ�t��7K�D�D���j�l*���M���R;#xJ�SPn�����n=j�n�5�����(�'{x�<z�~m��X��Rڴ`ߪ���h��7���X��g�k�ϳ�W�(��FK�&�����hϮ?#��P�?o�Q��W���ލ2]�F�N�������`��֣x�_��O��f8"(��
��!�T�M�n�ݡ��G�'���܁�σ���}d�z�7�`c�����޿��Q,yQ�8%�#�܄,��F���p�Ԋ�Oj���Ԩ�B�M�@j{����%}\��9�<M��C�� qF2��<~��sP7ٍ��qF�G||c��H��6�8܉���1��o�˶�^}͒�A�-?�ƚ�Pp����u��;cT�zl�@
"y��z�ǧM�Nj{Q~�|�A��0�͢�^Y����l^:t~��o��E�M���*t쎥�F�>wa�҆�ӹ�\|5�7J 8�����(�ц�ػ�~{��^�h�G�4��X�v	\�w@������(��@��ފ�&$�mK���-�������o,�9
F�����$�
�l0zq�й�t6^���*.I;itz�-mUҪO��6cpu����S����$���P)�Q拯F��x<stz$i�	��o�L�;���W;?�ʽ}\��e4�j�b��o�T+��ը�byث��
z[(�Kn�:���]g+�UԶ�K��3�����J���e�l)y��9-��>��[��W��r|5�G�У�o�_��$�G�xԫ��`Ry�� �N"b6Ģ�}�Y�3������q��E��^Ϋ��Y�|�R�X��� �o�G�\���+:�>�+̵��w�,
�|(�N�n{� &�lK7A%q�ld4�{'�Pj{pɛ��cY��1�ut�5+��zp�4>"Fu��T�`c�o�RD�g�6Sڿ��>5�=��Z�Ĥ���X��T4��Qԙ��J���|�6�����f�xOw2��'���U����{��]w�9���xSr�����8y�I�Ca����.���Wӛ�����ׇ$�͆Ǽ�
.F�ޞt�|{�Spz�cW|}�����~�f=sf�����4JIیPQ��K�c~�@��p��H�*���^�󃻍�%�jZ]�}5ܢX�$� �rh�d�k2�I�k�c�m��Zü!�	����i��X0��v%0b"b��c�قm&�@�s�.R�����E��k<�2�����o��v�w��?Vq�n{
z~2��    i�	15Vu� �	���O2�^W��Y=~��X]�#�mZ��N�c�7��O>����<Hķ�����p�<e���ߞ������5Q'Œ�lyȫ�0���%m���Cy��'�&]�� 
��Ǽ�F��i��BO�x�w,�y�H}^C��o�$1�(z�xc�?���՝[u$$���C�D�zK6r\Y�k[���U��{�]Y��o,��������z�5���ќ�*l�t��p����B#f���n�ǚ>��	����;7K���|(�a�V��}���PۇRo{�m��BM��q��
�ai})Rs�S|,U
c�~[J�[����8��b�[�)1̓W.:�u���]���޶������C^-=�F��Y�x����$�*���m�*+��[��!�RKo62��mLΏc�I��q�h��fkj�Jg��O��ݤ3H�E�M��g��G7������ t�xo&=jjv�L�Î�2ϒ���L�8���LG�1#a;Ж+:B^d��\g�;��Z���K?���>�ڐ�1ҟ^-�ͦMx�LG�2&���v��u^n�!8;�V�[m��냟&��f�o��Sύ�Xr��Ï�A��aIǹnS�1�ݓY<�;��;t^�k��k���Ǽ#� /���1�'_=�(>_3E���Jf4g��W���X5�ŝՃ�����V�rۘ11��Н�������OJ6�7���a�杘�	�$
��z�k��8i"�`�7Ƭ�e50o��y�*;g�z��R*�+k��N?'��C~P5����	���=�(��#~�_c缍~���w�t<�$� i֗W�F���BU��"�Bi�+�p�0������J]>��Y�}~�Bű���4��϶��d\	OG�N�Eci�μf��$��t,,���W����pQ�%>������,�y̏&O~�Xj��1�wX_ő^֎��w@��3&�_�o�>���M '�e_yi!jg�l�vvz�`��������aˣ�x�s��4Ǻ�D�q�=��ơ�Ӿם�K؈�݃^�?u��9���-������{�6nbc�_Ր��ݣ^Y8��R&t��J�t,,�O`�/Sc�oK0��&�&6�=���"�0��`:V�Jh��#o�S[�$��t$��n��OB`�RA����`�s`���[�a��cს�#?���jc�H���V�o�Y�kh�Ύ�(��`���
�����X%����e($"��#��]�c`��HY��l����-��qy�7������\O����|#�:�̪�s�e^?S<�N)R���t�j<18�cs�F�d/��������gUdV7�w� ����x&����놚�ã��6�c�6�'t���G�AH�1sYe;x��D���^E@+2�w�J��ȿ��=f� �e�c��P,>;���q�I�w��{]'W����G��ء]RK�����}pEyXR�yAr�8v�9E���Ӌ8�j|�:�}s�X������8�L�z:��T����hj���LG�Rג�/ �,�\��X�q:"v�g����R��;I��XƂwwg�Ҿ��2�a��b���in���HO�M��n�c4�6��d�g$�tL,�@��Z��3�Ei����Ɖ���e��k���A߷JV�jش����˃~L}ZF9�[}���(�=MPl$�o������j��� k�m.Ai�x;}:&V�rָ��71��9*��2���	��_2��XJā���3�s��q��$U�%mxv�l�l:2�������eڕ5Mf"�cbu�ىU<�:B�3�P��X��*��V�kC�6��=�ɸA���7���^�����Чx}}$۟��C��$/h�7��5���#m���SP%�ݘk��<�#y����R
)ı<����X?5�4Y����=���)���h#M�)I��x�c_X��wgq?%~����p���3�j.�_ş�C�D0ա*�q��Z�<��}���؁ubH8��1/�J~`|�L{���d�<�C͘�,��&-!���J�(���h͛����������N�D|Z.�~wF�$�w(z�mOKƪ�W���j�5T6i[6��n�6�6��?��c�mj�O�)o2L9YG��UP?0E���%��8>�5��c���U�}�uU�ce�e�X��[y��,N>T�:���4[�S�1>���b��Ú�݆:�JҰ\�c����-�nb5����Z�c����nqQ��2�U<�U�7o};���Jf�V�W��Z��on2R��P�*�_�1^g����a:���{���l�nӰTO�6W��o��)��sݺ��gUyю��<�e�M0�6Ъ�VY��~�����'�._�C^�rU�&��G��Wǌz6�F���!�x�}U��"N(K��Q�o��=ۛ��{�Mhx2��Ae��׷2Z_���]գRx��k��t���IvpY2V��p�al�/O��?�˒��k�(����Qr'�e��J�>��l�5�Ok�e�X��90��i���a��#��A��1�iS����`�X�ŵn��2�]������Z���1�:X�U����,��>0v3��FN '���b����-�Hmϸ��,�Ns�����/5���æyȃ�F��yM�mU�+H����~$�3쎀��=��X�C���\�K<̕Q[�s���|WW��ړjeM5�����|�7�mF�H+��e��{��D�N�m���]rYwyHE�l�|�n�L
f���{�C&�1�j�wjjd�{��xRE�Q�aù��N_�C~��B�G��4[��i�=����u,�J6J��C~���k�l�~x��x�Tlm��BF�<W� �u|�[.���Z��\d�V��z�&_��P��O�S�{���gl��j�=�>F;Eؓ]���X�S��N(�B����mY.�v���������[�q>o�X�ْ�)P^�^ܭ������~Z1�|�\t��Z�������|�~���e�\��Q�N#���q�%	�𨧠�����N�sĆ�kx�w�z�(7Ł���j��͹��I�$[�kx�w��R� iV���5<�1��k#�n͐��q�;<�����������C^8��v5[e:a��rx������\���5�����V�tddi��|��/D|�����⥦�hl!��G���ttZ^�r_q��#~P��n�8$�&*�kz��M���m_V,r���eY�JuUhgc����W��N��j,��K��:�%a���aKtE�o?�Y8 �����*�>���.���ʆ%���a5��s>_�-�^��`oy���ڎ~'��mZ�r��eiت�,������t�G�)F��a+GQ�~���^Y�oYت.5�\Ũs�)ɺI����&���Dtk�u�/ky̫�����m�f}�bŖ�<��D���e��)������Ghy��Am�$��c����N�S� �[(j��ښC���˃^�-�qױ}kWNV-n����`<~\@j��n�������ǦJ�R��1��9t�VGF��co��=�1��IH��#�\��0��m�5��RLr-��6�%b+�~1�@k*[L)?��-��j,Ꙁ�r����˞��T�qc(�N:q\"i�[&���f�gތ��PJ�	�e�X��1`�\�����]��EF�zeh�[%��N�$K�V�?:��̴|��1",�'
��P�=�u�_�����D,%O�v��d�o��tM�.G�r��|����)�d {�����k���~�D�P��q�m�fQc���:�3��p��N�p�1�_ǃ~h��@��=��m�$��a���h򽊇_��x�r;v\�)h��S�H�����A�������$D�#�;(JB���
q��{�����S7�5L��Zf�����2LF4���:<~��o(�^������m��Z��JG�w��8���Z.�(~ @�Mh��1��.q	����iI�]<�qԁH������q�zW��r�Õ�s���aU����>,1]�[��/O����T���#�=�� �  CyM�/t�ң��*���|�:�k���g+9���|c�*-�e�2n#�)�����8d�΋y6��kW�y$�D]8��\��Ǳ<�;-٦:���:�<��c����'��-jA����!�w�@d@�it�o�e���|���P�=l�	P����<�EGMy<�\ ���Pw�u]C�z�� �c֊��c8,�0f��g��y�z`e�Mɨce���C~p�w�yo�~۫���n��s��|^B�z��}Ņ�n�m�ɢ]�����mv�WG`����
���rD,����]�j�C���4�*m�E����ڎ��4��Wi����v���K�z�u��V�X���t���l�\2�Z�e����󎉝W��򷓣8�i��X^���?���O��C0>�;��I�^f/6��H2}��v��Q�a��������Uh�Q;���uh��^<��(ڣ*{s��ʋg��C%�m����K��N�����%��Rj��}������r��CB<�;����w/FO�!�N����Y��}�g��$���zQM ��@jd�<xza���4+v�>qR��<F�33)��5iL6o�}��g��*����gx���U�"�]�Xd`yz�]��ɥ�1w��G<V��&��E�7us�8����[j_��M�_ł���t�E�?Hw����َ��bPr��i���g$���{��vi�]:k�k�Xj�R�0�:X�2����Xj,#�nԼ�ە�l��r��#8�1<�%;Kv�w�d���j�fSf�Q�lPDix<<Eٸ֣�|�vT,��1�����I��ZF��%*v����^��v2����P��|��J�o%��#^8�J=���N{\�۞��E �}�Re�����<�nS@�(�R/Њ��?TR�"oVYx��d�rOy�N@��I����T��!?�Vw<����!I^��!?(	��%i���;uڎ��l�~�.��E���=z����<�:��wgQ��vV�8&�^Wx�f��B�]�X��V,ԧͥW2��+N�@R�;wf�omG��:"H ��L���oG�r7��(ب|H9<z�nI��������3�G׹ݷ�vD�V���-��oj*(���+W_�Rng����*����:���J[�	�������>�g�&��O���������w�ɸ���R^l����fR�T��G<v�}O|��5���G�L]��L7߱��'i�n��!���F���zY'0���ք>C�&����b\��q�$�WX�Ҫ��q�t<��{�ӧ\*�}.��A����k�ZsV0i��z���ƍ�8x�� �eaO95?��m���%���D��a����������U	���x��y� ���a�.Ď��v[[-a��#5ڔ#ͷD�6jɑ��^%���_{�q	˟cd�6��_�d��Ǒ��k�y��)�>��XX�%D{{����is��G�la���{��j��1|^�6E�ͳ�7���*;�c��#)4���J�z�}W�͎k�jD���c˃^y��{ߌ�0�HV�<�r����6w��Oɜ�q�M�.X�wk*����2�M���Y�:�/=��3�X*V�ݐ�Cu���k��G�X*VIUF�:]'�<�8�R���C�c�~�����ڱL���3U�R���c�m�c�ئ��u�;V1 ,۸���&��l��X��t�KD��w���.���a����U���	}oIq�UZ���!������S\O2��<�1 �9'���<nU�_�y�7��,K9O�z'KÏ�1�)Q�au�$DL���1�B���/���<��4���r�Hn��9����!/li���s<�q��<,D֤�5�W!zfh|���7h���c���̓~��֙`Q�	�X��4z�p����G�\_��;v�ϥQt8v,��ä/�%c-zq:�fUQ�%j��P��\crl5��O�FX.Vcq*�l6��&E�Z��"��:P�VSw@�$7�r�t�j3�F�)I��ta��bUn�IV�Hdd��%c5IU�l���|77�X��X��9P�}XLQ*-!��%c7ԙ�6WN�duK��c�X���ͤ]�/�a	cy��Y��޸��Ӊ���=�B����p"��ݼ���������r����ɱ����N�[�C�K�]W�L���G=�d]�:U`z�𸉯X��e��ڎI�9��n�x�cAj{�3���P4-I"�#^���oՉ:i����k#;gn����$���W'5A�aY�������Ce�یV��݉��;��=��H�]�b?��1?��F������TR���A�p��3��t�So��;z�c���aL�̎ec�H[L��~[J1=r,�H�������5F���R�ŕ�O^����^�ܕ���c�X�5��#�G�M��,{�j �S��4.����X*�����"���8幈�EKŶv�Y�`Ӌ/YZz'Z*VI`znW��Lwޖ����6��3��\�oҷ̾�X.�΁�Q�:���t$&P�􀇻󧊂���U&�'�gzģ7S��Q��U��#^HJ�dxKX��%���0�@g���]f��v�G��B|ݑ��}K���?X�pE�:�Vfn�O�<�ʁ\܈beS��+챹 �c�<�i�����<�1��݌����K�6����v�s.a����2��QkW~��ͯ{a��ϱL���+g^��.%_�?��m�����Jy���WE��@�Ll���cw�5�Wcמ���6������?Y��V&:N!,�XG|�RLI�5�ǒ�H���6�
@W���m{2я'��b5rP�	�a�uY�0��H�ֵ�,�S��p�C����sܛ� }�C��[�"M�5�f-W�X�|X��Y+��G�S��!�� �
�̙xS��!��0�C�V�u6�v�Ǽ��~��c��V�Izz<�;w�q���t���d�����޸/e�4��pcy���E�2ab_k&���9��{Р��U��=Q�>ǣ^�0��E�N�lC��z��{�{g����%!P����&dp�6����Cy�_�a8p��d7�ew|��A�CW���YQ�y)�cW?�c?����|Wc�>�����jr�L�S����Mk��������������-��8      �   �   x��λ�0����)|��ۡer4&����	F��/����ï`�v6m���̋����]��4��(�x����ڔ	���OY��#a�@�:�L �
t����J�J)Y�=����6��cd�a;p��唇	�B��ύ~�,�?f���B�'.IK      �   +   x�3�4B#3]#]CSK+Ss+C#.#N0�"���� �	�     