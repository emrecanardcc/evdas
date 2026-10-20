-- ========================================================
-- EVDAS / ORTAKPAY - PRODUCTION SUPABASE DATABASE SCHEMA
-- YÜKSEK PERFORMANS & İNDEKS OPTİMİZASYONLARI
-- Binlerce Eşzamanlı Kullanıcı & Hızlı RLS Sorguları İçin
-- Tamamen İdempotent (Tekrar tekrar çalıştırılabilir)
-- ========================================================

-- UUID eklentisi
create extension if not exists "uuid-ossp";

-- 1. KULLANICI PROFİLLERİ (PROFILES)
create table if not exists public.profiles (
    id uuid references auth.users on delete cascade primary key,
    full_name text not null,
    iban text,
    avatar_url text,
    phone text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.profiles enable row level security;

drop policy if exists "Profiller herkese okunabilir" on public.profiles;
create policy "Profiller herkese okunabilir"
    on public.profiles for select
    using (true);

drop policy if exists "Kullanıcı kendi profilini güncelleyebilir" on public.profiles;
create policy "Kullanıcı kendi profilini güncelleyebilir"
    on public.profiles for update
    using (auth.uid() = id);

drop policy if exists "Kullanıcı kendi profilini ekleyebilir" on public.profiles;
create policy "Kullanıcı kendi profilini ekleyebilir"
    on public.profiles for insert
    with check (auth.uid() = id);


-- 2. ORTAKLIK TÜRLERİ ENUM
do $$ begin
    create type public.partnership_type as enum ('home', 'office', 'travel', 'project', 'other');
exception
    when duplicate_object then null;
end $$;


-- 3. ORTAKLIKLAR / GRUPLAR (PARTNERSHIPS)
create table if not exists public.partnerships (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    type public.partnership_type default 'home' not null,
    invite_code text unique not null,
    currency text default 'TRY' not null,
    created_by uuid references public.profiles(id) on delete set null,
    settlement_day integer default 1 not null,
    custom_color bigint,
    custom_icon text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.partnerships add column if not exists settlement_day integer default 1;
alter table public.partnerships add column if not exists custom_color bigint;
alter table public.partnerships add column if not exists custom_icon text;

alter table public.partnerships enable row level security;

drop policy if exists "Üyeler kendi ortaklıklarını görebilir" on public.partnerships;
create policy "Üyeler kendi ortaklıklarını görebilir"
    on public.partnerships for select
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = partnerships.id
            and partnership_members.user_id = auth.uid()
        )
        or created_by = auth.uid()
    );

drop policy if exists "Kayıtlı kullanıcı yeni ortaklık oluşturabilir" on public.partnerships;
create policy "Kayıtlı kullanıcı yeni ortaklık oluşturabilir"
    on public.partnerships for insert
    with check (auth.uid() is not null);

drop policy if exists "Ortaklık yöneticisi ortaklığı güncelleyebilir" on public.partnerships;
drop policy if exists "Ortaklık üyeleri ortaklığı güncelleyebilir" on public.partnerships;
create policy "Ortaklık üyeleri ortaklığı güncelleyebilir"
    on public.partnerships for update
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = partnerships.id
            and partnership_members.user_id = auth.uid()
        )
        or created_by = auth.uid()
    );


-- 4. ORTAKLIK ÜYELERİ (PARTNERSHIP MEMBERS)
create table if not exists public.partnership_members (
    id uuid default gen_random_uuid() primary key,
    partnership_id uuid references public.partnerships(id) on delete cascade not null,
    user_id uuid references public.profiles(id) on delete cascade not null,
    display_name text not null,
    role text default 'member' not null,
    iban text,
    joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(partnership_id, user_id)
);

alter table public.partnership_members enable row level security;

drop policy if exists "Ortaklık üyeleri listesi okunabilir" on public.partnership_members;
create policy "Ortaklık üyeleri listesi okunabilir"
    on public.partnership_members for select
    using (
        exists (
            select 1 from public.partnership_members as m
            where m.partnership_id = partnership_members.partnership_id
            and m.user_id = auth.uid()
        )
    );

drop policy if exists "Ortaklığa üye ekleme" on public.partnership_members;
create policy "Ortaklığa üye ekleme"
    on public.partnership_members for insert
    with check (auth.uid() is not null);


-- ========================================================
-- KRİTİK İŞ KURALI: MAKSİMUM 6 ORTAK SINIRI TRIGGER'I
-- ========================================================
create or replace function public.check_max_partnership_members()
returns trigger as $$
declare
    current_count integer;
begin
    select count(*) into current_count
    from public.partnership_members
    where partnership_id = new.partnership_id;

    if current_count >= 6 then
        raise exception 'Bu ortaklık maksimum kapasitesine ulaştı! Bir ortaklıkta en fazla 6 üye yer alabilir.';
    end if;

    return new;
end;
$$ language plpgsql;

drop trigger if exists enforce_max_members on public.partnership_members;
create trigger enforce_max_members
before insert on public.partnership_members
for each row execute function public.check_max_partnership_members();


-- 5. HARCAMA TİPİ ENUM
do $$ begin
    create type public.expense_type as enum ('joint', 'personal_debt', 'settlement');
exception
    when duplicate_object then null;
end $$;


-- 6. HARCAMALAR (EXPENSES)
create table if not exists public.expenses (
    id uuid default gen_random_uuid() primary key,
    partnership_id uuid references public.partnerships(id) on delete cascade not null,
    title text not null,
    amount numeric(12, 2) not null check (amount > 0),
    type public.expense_type default 'joint' not null,
    category text default 'diger' not null,
    paid_by_member_id uuid references public.partnership_members(id) on delete cascade not null,
    debtor_member_id uuid references public.partnership_members(id) on delete set null,
    expense_date timestamp with time zone default timezone('utc'::text, now()) not null,
    notes text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.expenses enable row level security;

drop policy if exists "Ortaklık üyeleri harcamaları görebilir" on public.expenses;
create policy "Ortaklık üyeleri harcamaları görebilir"
    on public.expenses for select
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = expenses.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );

drop policy if exists "Ortaklık üyeleri harcama ekleyebilir" on public.expenses;
create policy "Ortaklık üyeleri harcama ekleyebilir"
    on public.expenses for insert
    with check (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = expenses.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );

drop policy if exists "Ortaklık üyeleri harcama güncelleyebilir" on public.expenses;
create policy "Ortaklık üyeleri harcama güncelleyebilir"
    on public.expenses for update
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = expenses.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );

drop policy if exists "Ortaklık üyeleri harcama silebilir" on public.expenses;
create policy "Ortaklık üyeleri harcama silebilir"
    on public.expenses for delete
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = expenses.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );


-- 7. KISMİ ÖDEMELER & ÇİFT TARAFLI KARŞILIKLI ONAY TABLOSU
do $$ begin
    create type public.payment_status as enum ('pending', 'confirmed', 'rejected');
exception
    when duplicate_object then null;
end $$;

create table if not exists public.payment_requests (
    id uuid default gen_random_uuid() primary key,
    partnership_id uuid references public.partnerships(id) on delete cascade not null,
    from_member_id uuid references public.partnership_members(id) on delete cascade not null,
    to_member_id uuid references public.partnership_members(id) on delete cascade not null,
    amount numeric(12, 2) not null check (amount > 0),
    status public.payment_status default 'pending' not null,
    note text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    reviewed_at timestamp with time zone
);

alter table public.payment_requests enable row level security;

drop policy if exists "Ortaklık üyeleri ödeme bildirimlerini görebilir" on public.payment_requests;
create policy "Ortaklık üyeleri ödeme bildirimlerini görebilir"
    on public.payment_requests for select
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = payment_requests.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );

drop policy if exists "Ortaklık üyeleri ödeme bildirimi oluşturabilir" on public.payment_requests;
create policy "Ortaklık üyeleri ödeme bildirimi oluşturabilir"
    on public.payment_requests for insert
    with check (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = payment_requests.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );

drop policy if exists "Alacaklı ödemeyi onaylayabilir veya reddedebilir" on public.payment_requests;
create policy "Alacaklı ödemeyi onaylayabilir veya reddedebilir"
    on public.payment_requests for update
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.id = payment_requests.to_member_id
            and partnership_members.user_id = auth.uid()
        )
    );


-- 8. DÖNEMSEL HESAP KAPATMA (SETTLEMENTS)
create table if not exists public.settlements (
    id uuid default gen_random_uuid() primary key,
    partnership_id uuid references public.partnerships(id) on delete cascade not null,
    period_title text not null,
    settled_by uuid references public.profiles(id),
    total_amount numeric(12, 2) not null,
    settlement_data jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.settlements enable row level security;

drop policy if exists "Ortaklık üyeleri ödeşme geçmişini görebilir" on public.settlements;
create policy "Ortaklık üyeleri ödeşme geçmişini görebilir"
    on public.settlements for select
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = settlements.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );


-- 8b. ORTAK KARAR & ONAY TALEPLERİ (APPROVAL REQUESTS)
do $$ begin
    create type public.approval_type as enum ('expense_delete', 'leave_partnership', 'delete_partnership');
exception
    when duplicate_object then null;
end $$;

do $$ begin
    create type public.approval_status as enum ('pending', 'approved', 'rejected');
exception
    when duplicate_object then null;
end $$;

create table if not exists public.approval_requests (
    id uuid default gen_random_uuid() primary key,
    partnership_id uuid references public.partnerships(id) on delete cascade not null,
    type public.approval_type default 'expense_delete' not null,
    target_id text not null,
    title text not null,
    requested_by_member_id uuid references public.partnership_members(id) on delete cascade not null,
    requested_by_name text not null,
    approvals jsonb default '[]'::jsonb not null,
    rejections jsonb default '[]'::jsonb not null,
    required_count integer default 1 not null,
    status public.approval_status default 'pending' not null,
    metadata jsonb default '{}'::jsonb not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.approval_requests enable row level security;

drop policy if exists "Ortaklık üyeleri onay taleplerini görebilir" on public.approval_requests;
create policy "Ortaklık üyeleri onay taleplerini görebilir"
    on public.approval_requests for select
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = approval_requests.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );

drop policy if exists "Ortaklık üyeleri onay talebi oluşturabilir" on public.approval_requests;
create policy "Ortaklık üyeleri onay talebi oluşturabilir"
    on public.approval_requests for insert
    with check (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = approval_requests.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );

drop policy if exists "Ortaklık üyeleri onay talebini oylayabilir/güncelleyebilir" on public.approval_requests;
create policy "Ortaklık üyeleri onay talebini oylayabilir/güncelleyebilir"
    on public.approval_requests for update
    using (
        exists (
            select 1 from public.partnership_members
            where partnership_members.partnership_id = approval_requests.partnership_id
            and partnership_members.user_id = auth.uid()
        )
    );


-- ========================================================
-- ⚡ 9. VERİTABANI PERFORMANS İNDEKSLERİ (GEREKSİZ YÜKÜ VE İSTEKLERİ ÖNLER)
-- RLS politikalarının ve listeleme sorgularının anında (O(1)) çalışmasını sağlar.
-- ========================================================

-- RLS hızlandırma için bileşik indeks (Her sorguda taranır)
create index if not exists idx_pm_composite_lookup
    on public.partnership_members (partnership_id, user_id);

create index if not exists idx_pm_user_id
    on public.partnership_members (user_id);

-- Harcamaların ters kronolojik sıralı hızlı getirilmesi için indeks
create index if not exists idx_expenses_partnership_date
    on public.expenses (partnership_id, expense_date desc);

-- Raporlar için kategori indeksi
create index if not exists idx_expenses_category_stats
    on public.expenses (partnership_id, category);

-- Bekleyen ödemeler ve durum filtreleme indeksi
create index if not exists idx_payments_partnership_status
    on public.payment_requests (partnership_id, status);

-- Davet kodu hızlı arama indeksi
create index if not exists idx_partnerships_invite_code
    on public.partnerships (invite_code);

-- Hesap kapatma geçmişi indeksi
create index if not exists idx_settlements_partnership_date
    on public.settlements (partnership_id, created_at desc);

-- Onay talepleri hızlı filtreleme indeksi
create index if not exists idx_approval_requests_p_status
    on public.approval_requests (partnership_id, status);


-- ========================================================
-- 10. AUTH KAYDI OLUNCA OTOMATİK PROFİL OLUŞTURMA TRIGGER'I
-- ========================================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, full_name, iban)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'iban'
    );
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();


-- ========================================================
-- 11. APPLE GUIDELINE 5.1.1(v) HESAP VE TÜM VERİLERİ SİLME RPC
-- ========================================================
create or replace function public.delete_user_account()
returns void as $$
declare
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'Giriş yapmış kullanıcı bulunamadı';
    end if;

    -- Kullanıcının ortaklık üyeliklerini sil:
    delete from public.partnership_members where user_id = v_user_id;

    -- Kullanıcının oluşturduğu ve başka üyesi kalmayan ortaklıkları sil:
    delete from public.partnerships p
    where p.created_by = v_user_id
      and not exists (
          select 1 from public.partnership_members pm 
          where pm.partnership_id = p.id
      );

    -- Profil kaydını sil:
    delete from public.profiles where id = v_user_id;

    -- auth.users kaydını sil:
    delete from auth.users where id = v_user_id;
end;
$$ language plpgsql security definer;
