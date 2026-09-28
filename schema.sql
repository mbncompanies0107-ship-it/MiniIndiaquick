-- Mini India Ireland — PostgreSQL/PostGIS-ready MVP schema
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TYPE user_role AS ENUM ('CUSTOMER','ADMIN','STORE_OPERATOR','RIDER');
CREATE TYPE store_status AS ENUM ('OPEN','BUSY','CLOSED');
CREATE TYPE order_status AS ENUM ('PLACED','CONFIRMED','PICKING','PACKED','RIDER_ASSIGNED','OUT_FOR_DELIVERY','DELIVERED','CANCELLED');

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email text UNIQUE NOT NULL, full_name text NOT NULL,
  phone text, role user_role NOT NULL DEFAULT 'CUSTOMER', password_hash text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE stores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, address text NOT NULL, region text NOT NULL,
  eircode text, latitude double precision, longitude double precision,
  location geography(Point,4326), radius_km numeric(5,2) NOT NULL DEFAULT 6.00, max_eta_minutes integer NOT NULL DEFAULT 60,
  status store_status NOT NULL DEFAULT 'OPEN', opening_time time NOT NULL DEFAULT '08:00', closing_time time NOT NULL DEFAULT '23:00',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE INDEX stores_location_gix ON stores USING GIST(location);
CREATE TABLE categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text UNIQUE NOT NULL, sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category_id uuid REFERENCES categories(id), name text NOT NULL,
  brand text, size text, sku text UNIQUE NOT NULL, price_eur numeric(10,2) NOT NULL, compare_at_eur numeric(10,2),
  image_url text, description text, ingredients text, allergens text, origin text, rating numeric(2,1) DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE store_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), store_id uuid NOT NULL REFERENCES stores(id), product_id uuid NOT NULL REFERENCES products(id),
  stock integer NOT NULL DEFAULT 0 CHECK(stock>=0), reserved integer NOT NULL DEFAULT 0 CHECK(reserved>=0), reorder_threshold integer NOT NULL DEFAULT 10,
  enabled boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(store_id,product_id)
);
CREATE TABLE addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id), label text, address_line1 text NOT NULL,
  address_line2 text, city text NOT NULL, county text, eircode text, latitude double precision, longitude double precision,
  location geography(Point,4326), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE INDEX addresses_location_gix ON addresses USING GIST(location);
CREATE TABLE carts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id), store_id uuid REFERENCES stores(id), created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
CREATE TABLE cart_items (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), cart_id uuid NOT NULL REFERENCES carts(id) ON DELETE CASCADE, product_id uuid NOT NULL REFERENCES products(id), quantity integer NOT NULL CHECK(quantity>0), created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(), UNIQUE(cart_id,product_id));
CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_number text UNIQUE NOT NULL, user_id uuid REFERENCES users(id), store_id uuid REFERENCES stores(id), address_id uuid REFERENCES addresses(id),
  status order_status NOT NULL DEFAULT 'PLACED', subtotal_eur numeric(10,2) NOT NULL, delivery_fee_eur numeric(10,2) NOT NULL, discount_eur numeric(10,2) NOT NULL DEFAULT 0, total_eur numeric(10,2) NOT NULL,
  estimated_delivery_minutes integer, delivery_instructions text, placed_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE order_items (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE, product_id uuid NOT NULL REFERENCES products(id), product_name text NOT NULL, quantity integer NOT NULL, unit_price_eur numeric(10,2) NOT NULL, created_at timestamptz DEFAULT now());
CREATE TABLE payments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES orders(id), provider text NOT NULL DEFAULT 'demo', provider_payment_id text, status text NOT NULL DEFAULT 'succeeded', amount_eur numeric(10,2) NOT NULL, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
CREATE TABLE riders (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid UNIQUE NOT NULL REFERENCES users(id), vehicle_type text, is_online boolean DEFAULT false, current_latitude double precision, current_longitude double precision, rating numeric(2,1) DEFAULT 5.0, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
CREATE TABLE deliveries (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid UNIQUE NOT NULL REFERENCES orders(id), rider_id uuid REFERENCES riders(id), status order_status NOT NULL DEFAULT 'RIDER_ASSIGNED', otp_hash text, assigned_at timestamptz, picked_up_at timestamptz, delivered_at timestamptz, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
CREATE TABLE delivery_status_history (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), delivery_id uuid NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE, status order_status NOT NULL, note text, created_at timestamptz DEFAULT now());
CREATE TABLE promotions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE, description text, percent_off numeric(5,2), amount_off_eur numeric(10,2), min_order_eur numeric(10,2), active boolean DEFAULT true, starts_at timestamptz, ends_at timestamptz, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
CREATE TABLE reviews (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id), product_id uuid REFERENCES products(id), order_id uuid REFERENCES orders(id), rating integer CHECK(rating BETWEEN 1 AND 5), body text, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now());
CREATE TABLE notifications (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id), order_id uuid REFERENCES orders(id), title text NOT NULL, body text NOT NULL, read_at timestamptz, created_at timestamptz DEFAULT now());

-- Delivery fee policy: 0–3 km €2.99, 3–6 km €4.99, orders over €50 free.
-- Delivery decision: distance <= store.radius_km AND estimated ETA <= store.max_eta_minutes AND store.status='OPEN' AND required inventory available.
-- Select lowest ETA, then shortest distance, then highest available inventory.

INSERT INTO stores (name,address,region,eircode,latitude,longitude,location) VALUES
('Mini India Dublin City','28 Westmoreland Street, Dublin 2, Ireland','Dublin','D02 X285',53.3461,-6.2592,ST_SetSRID(ST_MakePoint(-6.2592,53.3461),4326)),
('Mini India Sandyford','7 Blackthorn Avenue, Sandyford, Dublin 18, Ireland','Dublin','D18 K2P3',53.2742,-6.2104,ST_SetSRID(ST_MakePoint(-6.2104,53.2742),4326)),
('Mini India Limerick','Unit 1, Chatori, Singland, Limerick, V94 F8F2, Ireland','Limerick','V94 F8F2',52.6595,-8.6151,ST_SetSRID(ST_MakePoint(-8.6151,52.6595),4326));

-- API map: POST /api/auth/login|register; GET /api/stores|nearest|{id};
-- GET /api/products|{id}|categories; GET/PATCH /api/inventory; GET/POST/PATCH/DELETE /api/cart/items;
-- POST /api/delivery/check; GET /api/delivery/estimate; POST/GET /api/orders; GET /api/orders/{id};
-- GET /api/orders/{id}/tracking; GET /api/rider/orders; POST /api/rider/orders/{id}/accept|status;
-- GET /api/admin/dashboard|orders|analytics.
