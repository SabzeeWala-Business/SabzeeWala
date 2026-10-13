# Sabzee Web Admin

**Live Production Panel:** [https://sabzeeewala.netlify.app/](https://sabzeeewala.netlify.app/)

Business control panel for the Sabzee Flutter app. All catalog, order, and customer
data syncs through the same Supabase project as the mobile app.

## Features

- **Auth**
  - Email + password via Supabase Auth (admin role required on `profiles`)
  - Phone OTP via MSG91 (same Express backend as the Flutter app)
- **Menu & catalog** — categories, sub-categories, products/variants, image upload, CSV bulk import, taxes & charges
- **Orders** — realtime alerts, accept/reject, status updates, COD vs online filters, print/share invoices
- **Customers** — spend profile, order history, block/unblock, employees, companies
- **Analytics** — today / week / month reports, COD vs online, CSV export
- **Outlets** — store outlet CRUD

## Run locally

```bash
# 1) Auth backend (MSG91 OTP) — from repo root
cd backend
cp .env.example .env   # fill MSG91 keys
npm install
npm run dev

# 2) Web admin
cd ../web_admin
npm install
npm run dev
```

Open http://localhost:5173

### Admin login

| Method | How |
|--------|-----|
| Phone OTP | Use `9876543210` (demo, any OTP) or a real number with `profiles.role = 'admin'` |
| Email | Create user in Supabase Auth → set matching `profiles.id` + `role = 'admin'` |

## Optional SQL

Run `supabase_admin_extras.sql` in the Supabase SQL editor for service charge columns,
employees/companies tables, and order invoice fields.

## Env

```
VITE_AUTH_API_URL=http://localhost:5000
```

In Vite dev mode the `/api` path is proxied to port 5000 automatically.
