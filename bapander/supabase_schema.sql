-- ============================================================
-- BAPANDER DATABASE SCHEMA FOR SUPABASE
-- Jalankan di: Supabase Dashboard → SQL Editor
-- ============================================================

-- ── USERS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  photo TEXT DEFAULT '',
  online BOOLEAN DEFAULT false,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  language TEXT DEFAULT 'id',
  bio TEXT DEFAULT '',
  gender TEXT DEFAULT 'L',
  age INTEGER DEFAULT 0,
  anonymous_mode BOOLEAN DEFAULT false,
  latitude FLOAT,
  longitude FLOAT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read all users" ON public.users
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ── CHATS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.chats (
  id TEXT PRIMARY KEY,
  type TEXT DEFAULT 'private',
  members TEXT[] NOT NULL DEFAULT '{}',
  group_id TEXT,
  last_message TEXT DEFAULT '',
  last_timestamp TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Chat members can read" ON public.chats
  FOR SELECT USING (auth.uid()::text = ANY(members));

CREATE POLICY "Authenticated can create chat" ON public.chats
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Chat members can update" ON public.chats
  FOR UPDATE USING (auth.uid()::text = ANY(members));

-- ── MESSAGES ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id TEXT NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender UUID NOT NULL,
  text TEXT DEFAULT '',
  type TEXT DEFAULT 'text',
  media_url TEXT DEFAULT '',
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'sent',
  duration INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Chat members can read messages" ON public.messages
  FOR SELECT USING (
    auth.uid()::text = ANY(
      SELECT unnest(members) FROM public.chats WHERE id = chat_id
    )
  );

CREATE POLICY "Authenticated can send messages" ON public.messages
  FOR INSERT WITH CHECK (auth.uid() = sender);

CREATE POLICY "Sender can update message status" ON public.messages
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Enable realtime for messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;

-- ── GROUPS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  photo TEXT DEFAULT '',
  description TEXT DEFAULT '',
  members TEXT[] NOT NULL DEFAULT '{}',
  admin TEXT[] NOT NULL DEFAULT '{}',
  language TEXT DEFAULT 'id',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group members can read" ON public.groups
  FOR SELECT USING (auth.uid()::text = ANY(members));

CREATE POLICY "Authenticated can create group" ON public.groups
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can update group" ON public.groups
  FOR UPDATE USING (auth.uid()::text = ANY(admin));

-- ── CALLS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caller UUID NOT NULL,
  receiver UUID NOT NULL,
  status TEXT DEFAULT 'ringing',
  offer JSONB DEFAULT '{}',
  answer JSONB DEFAULT '{}',
  caller_candidates JSONB[] DEFAULT '{}',
  receiver_candidates JSONB[] DEFAULT '{}',
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Call participants can access" ON public.calls
  FOR ALL USING (auth.uid() = caller OR auth.uid() = receiver);

CREATE POLICY "Authenticated can create call" ON public.calls
  FOR INSERT WITH CHECK (auth.uid() = caller);

ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;

-- ── PRODUCTS (MARKETPLACE) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL,
  seller_name TEXT NOT NULL,
  seller_photo TEXT DEFAULT '',
  seller_anonymous BOOLEAN DEFAULT false,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  price FLOAT NOT NULL,
  images TEXT[] DEFAULT '{}',
  category TEXT DEFAULT 'lainnya',
  condition TEXT DEFAULT 'baru',
  status TEXT DEFAULT 'aktif',
  location TEXT DEFAULT '',
  latitude FLOAT,
  longitude FLOAT,
  view_count INTEGER DEFAULT 0,
  saved_by TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active products" ON public.products
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Sellers can insert products" ON public.products
  FOR INSERT WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Sellers can update own products" ON public.products
  FOR UPDATE USING (auth.uid() = seller_id OR auth.role() = 'authenticated');

-- ── AUCTIONS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.auctions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL,
  seller_name TEXT NOT NULL,
  seller_photo TEXT DEFAULT '',
  seller_anonymous BOOLEAN DEFAULT false,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  images TEXT[] DEFAULT '{}',
  category TEXT DEFAULT 'lainnya',
  condition TEXT DEFAULT 'baru',
  start_price FLOAT NOT NULL,
  current_price FLOAT NOT NULL,
  buy_now_price FLOAT,
  min_bid_increment FLOAT DEFAULT 1000,
  highest_bidder_id UUID,
  highest_bidder_name TEXT,
  highest_bidder_anonymous BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'berlangsung',
  start_time TIMESTAMPTZ DEFAULT NOW(),
  end_time TIMESTAMPTZ NOT NULL,
  location TEXT DEFAULT '',
  total_bids INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.auctions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read auctions" ON public.auctions
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Sellers can create auctions" ON public.auctions
  FOR INSERT WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Anyone can update auction price" ON public.auctions
  FOR UPDATE USING (auth.role() = 'authenticated');

ALTER PUBLICATION supabase_realtime ADD TABLE public.auctions;

-- ── BIDS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bids (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auction_id UUID NOT NULL REFERENCES public.auctions(id) ON DELETE CASCADE,
  bidder_id UUID NOT NULL,
  bidder_name TEXT NOT NULL,
  bidder_anonymous BOOLEAN DEFAULT false,
  amount FLOAT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.bids ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read bids" ON public.bids
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated can place bids" ON public.bids
  FOR INSERT WITH CHECK (auth.uid() = bidder_id);

ALTER PUBLICATION supabase_realtime ADD TABLE public.bids;

-- ── STORAGE BUCKETS ──────────────────────────────────────────
-- Jalankan di Storage settings atau SQL:
INSERT INTO storage.buckets (id, name, public) 
VALUES ('media', 'media', true)
ON CONFLICT DO NOTHING;

CREATE POLICY "Anyone can read media" ON storage.objects
  FOR SELECT USING (bucket_id = 'media');

CREATE POLICY "Authenticated can upload media" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'media' AND auth.role() = 'authenticated'
  );

-- ── STATUSES ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  user_name TEXT NOT NULL DEFAULT '',
  user_photo TEXT DEFAULT '',
  type TEXT DEFAULT 'text',
  content TEXT NOT NULL,
  caption TEXT,
  background_color TEXT DEFAULT '#0F6E56',
  font_color TEXT DEFAULT '#FFFFFF',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours',
  viewed_by TEXT[] DEFAULT '{}',
  is_anonymous BOOLEAN DEFAULT false
);

ALTER TABLE public.statuses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active statuses" ON public.statuses
  FOR SELECT USING (auth.role() = 'authenticated' AND expires_at > NOW());

CREATE POLICY "Users can create status" ON public.statuses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own status" ON public.statuses
  FOR UPDATE USING (auth.uid() = user_id OR auth.role() = 'authenticated');

CREATE POLICY "Users can delete own status" ON public.statuses
  FOR DELETE USING (auth.uid() = user_id);

ALTER PUBLICATION supabase_realtime ADD TABLE public.statuses;
