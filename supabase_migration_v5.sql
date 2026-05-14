-- ═══════════════════════════════════════════════════════════════
-- MIGRASI SUPABASE v5 — Tabel Bengkel (Services, Vehicles, WorkOrders)
-- Jalankan di Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- 1. Tabel Katalog Jasa Bengkel
CREATE TABLE IF NOT EXISTS public.services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  description TEXT,
  price DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  estimated_minutes INTEGER NOT NULL DEFAULT 30,
  category VARCHAR(50) NOT NULL DEFAULT 'umum',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Tabel Kendaraan Pelanggan
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name VARCHAR(200) NOT NULL,
  phone_number VARCHAR(20),
  plate_number VARCHAR(15) NOT NULL,
  vehicle_brand VARCHAR(100),
  vehicle_type VARCHAR(100),
  vehicle_year INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Tabel Work Orders (Antrian Bengkel)
CREATE TABLE IF NOT EXISTS public.work_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no VARCHAR(30) NOT NULL UNIQUE,
  vehicle_id UUID NOT NULL REFERENCES public.vehicles(id),
  user_id UUID NOT NULL REFERENCES public.users(id),
  status VARCHAR(20) NOT NULL DEFAULT 'waiting',
  complaint TEXT,
  diagnosis TEXT,
  total_service DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_parts DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  grand_total DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  transaction_id UUID REFERENCES public.transactions(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- 4. Tambah kolom baru ke tabel transactions
ALTER TABLE public.transactions 
  ADD COLUMN IF NOT EXISTS customer_name VARCHAR(200);

-- 5. Tambah kolom baru ke tabel transaction_items
ALTER TABLE public.transaction_items 
  ADD COLUMN IF NOT EXISTS item_type VARCHAR(20) NOT NULL DEFAULT 'product';

ALTER TABLE public.transaction_items 
  ADD COLUMN IF NOT EXISTS service_id UUID REFERENCES public.services(id);

-- 6. Buat product_id nullable (jika belum)
ALTER TABLE public.transaction_items 
  ALTER COLUMN product_id DROP NOT NULL;

-- ═══════════════════════════════════════════════════════════════
-- RLS (Row Level Security) — Enable untuk semua tabel baru
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_orders ENABLE ROW LEVEL SECURITY;

-- Policy: Semua user bisa baca & tulis (sesuaikan jika perlu)
CREATE POLICY "Allow all access to services" ON public.services
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow all access to vehicles" ON public.vehicles
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow all access to work_orders" ON public.work_orders
  FOR ALL USING (true) WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════
-- INDEX untuk performa query
-- ═══════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_services_category ON public.services(category);
CREATE INDEX IF NOT EXISTS idx_services_active ON public.services(is_active);
CREATE INDEX IF NOT EXISTS idx_vehicles_plate ON public.vehicles(plate_number);
CREATE INDEX IF NOT EXISTS idx_vehicles_customer ON public.vehicles(customer_name);
CREATE INDEX IF NOT EXISTS idx_work_orders_status ON public.work_orders(status);
CREATE INDEX IF NOT EXISTS idx_work_orders_vehicle ON public.work_orders(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_work_orders_created ON public.work_orders(created_at);
CREATE INDEX IF NOT EXISTS idx_transaction_items_type ON public.transaction_items(item_type);
CREATE INDEX IF NOT EXISTS idx_transaction_items_service ON public.transaction_items(service_id);
