# Mini India Ireland — Quick Commerce MVP

A polished, responsive stakeholder-demo MVP for an Irish Indian-grocery delivery experience. The prototype runs as a self-contained static SPA so the full customer, store, rider, and admin journeys work immediately without external services. The product catalog is imported from the supplied `Mini_India_Product_Catalog.xlsx` workbook.

## What is built

- Customer storefront with Mini India Ireland brand, search, category filters, 852 imported products from the supplied workbook, EUR pricing, product details, cart, discount and delivery-fee rules.
- Delivery eligibility modal with demo Dublin 2, Sandyford, Limerick, and outside-zone locations.
- Store selection data for Dublin City, Sandyford, and Limerick. Delivery logic follows: within approximately 6 km **and** estimated delivery time ≤ 60 minutes, with store status and availability represented in state.
- Checkout with Irish address fields, ASAP/scheduled options, demo card, Apple Pay and Google Pay choices.
- Order confirmation and live tracking timeline with a simulated map, rider contact buttons, and status progression.
- Store operator dashboard with open/closed status, live queue, picking checklist, packed hand-off state.
- Mobile-first rider dashboard with online toggle, delivery route, earnings, delivery status progression, and demo OTP 1234 completion.
- Admin dashboard with metrics, charts, order queue, store management, inventory table, toggles, and operational demo controls.
- Accessible semantic controls, focus states, responsive desktop/mobile layouts, empty/error states, toast feedback, and graceful fallback when catalog image references are unavailable.
- LocalStorage persistence for demo cart, location, order, and workflow state.

## Run it

Static preview (no install required):

```bash
cd /data
python3 -m http.server 4173
```

Open <http://localhost:4173>.

The current sandbox contains `index.html`, `style.css`, `catalog.js`, and `app.js`. `catalog.js` is generated from the uploaded workbook and contains 852 catalog records, website category mappings, prices, sale prices, availability, product URLs, and 719 usable image references with emoji fallback artwork.

## Demo credentials

The static MVP does not require authentication. For the future backend, use these development-only identities:

- Admin: `admin@miniindia.ie`
- Store operator: `store@miniindia.ie`
- Rider: `rider@miniindia.ie`
- Customer: `customer@example.com`
- Demo password: `DemoMiniIndia2026!` (development only; rotate before any deployment)

## Presentation flow

1. Open the homepage and click **Enter your Eircode** → **Demo Dublin 2**.
2. Click **Shop now**, add 5–6 products, and open the basket.
3. Continue to checkout and place a demo order.
4. Open **Track order** and advance the status timeline.
5. Open **Operations** → switch to **Store dashboard** and use **Start picking**, checklist controls, and **Mark packed**.
6. Open **Rider app**, accept/progress the delivery, and finish with demo OTP `1234`.
7. Return to customer tracking and show **Delivered**.
8. Open **Operations** → **Stores** or **Inventory** to show controls and stock health.
9. The homepage includes **Open demo order** for the seeded primary stakeholder scenario `#MI-10482`.

## Environment variables

The static demo does not read secrets. `.env.example` documents the intended production integration points:

- `DATABASE_URL`
- `REDIS_URL`
- `GOOGLE_MAPS_API_KEY`
- `STRIPE_SECRET_KEY`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `JWT_SECRET`
- `NEXT_PUBLIC_API_URL`

Never commit real values.

## Database setup

`schema.sql` contains a PostgreSQL/PostGIS-ready relational model with UUID primary keys, created/updated timestamps, soft-delete fields where appropriate, store/product/inventory/order/rider/tracking entities, and indexes. `catalog-seed.sql` contains 852 idempotent product upserts generated from the supplied workbook. It maps website categories into the storefront categories, preserves EUR prices, sale prices, image references, and website IDs as SKUs.

For a real backend:

1. Create a PostgreSQL database and enable `postgis`.
2. Run `psql "$DATABASE_URL" -f schema.sql`.
3. Run `psql "$DATABASE_URL" -f catalog-seed.sql`.
4. Add a backend API using the endpoint map in `schema.sql` and the product/state contracts in `app.js`.
5. Replace the demo LocalStorage service with API calls, keeping the same delivery-engine rule and UI states.

## Mocked vs production-ready

**Mocked:** authentication, payment authorization, geocoding/maps, rider GPS, notifications, persistence, analytics aggregation, and API transport. The catalog preserves 719 usable image references from the workbook, with CSS/emoji fallback art if an image is unavailable.

**Production-ready direction:** modular UI routes/state, realistic domain model, Irish market copy/data, store/zone rules, delivery-fee calculation, EUR formatting, role-specific surfaces, responsive layout, and clear seams for Next.js/API/Postgres/Redis/Stripe/Maps integration.

## Recommended next steps

1. Move the domain data into PostgreSQL and add FastAPI/Next API routes.
2. Add Eircode geocoding and PostGIS distance checks; persist store coordinates.
3. Add real auth/role guards and Stripe Payment Element.
4. Replace the simulated rider map with a provider integration and web socket/SSE order events.
5. Add automated component/E2E tests around eligibility, cart totals, inventory reservation, checkout idempotency, and status transitions.
6. Add image CDN/product photography and content moderation/stock workflows before launch.
