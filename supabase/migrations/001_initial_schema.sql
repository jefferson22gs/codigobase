-- ============================================================================
-- Codigo Base Platform - Initial Schema Migration
-- Target: Supabase (PostgreSQL 15+)
-- Tables: 30
-- Run in: Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- 0. EXTENSIONS & UTILITY FUNCTIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Auto-update updated_at on any table that has the column
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Helper: returns TRUE when the current JWT user has role = 'admin' in profiles
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid()
          AND role = 'admin'
    );
$$;

-- Auto-create a profile row when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (id, nome, avatar_url, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.email),
        COALESCE(NEW.raw_user_meta_data ->> 'avatar_url', ''),
        'admin'
    );
    RETURN NEW;
END;
$$;

-- Trigger on auth.users (Supabase managed schema)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 1. PROFILES (extends auth.users)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nome        TEXT NOT NULL DEFAULT '',
    avatar_url  TEXT NOT NULL DEFAULT '',
    role        TEXT NOT NULL DEFAULT 'admin',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policies: any authenticated user can read own profile; admins can do everything
CREATE POLICY profiles_select_own ON public.profiles
    FOR SELECT TO authenticated
    USING (id = auth.uid() OR public.is_admin());

CREATE POLICY profiles_update_own ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid() OR public.is_admin())
    WITH CHECK (id = auth.uid() OR public.is_admin());

CREATE POLICY profiles_insert_admin ON public.profiles
    FOR INSERT TO authenticated
    WITH CHECK (public.is_admin() OR id = auth.uid());

CREATE POLICY profiles_delete_admin ON public.profiles
    FOR DELETE TO authenticated
    USING (public.is_admin());

-- ============================================================================
-- 2. USER INVITES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_invites (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT NOT NULL,
    role        TEXT NOT NULL DEFAULT 'admin',
    token       UUID NOT NULL DEFAULT gen_random_uuid(),
    expires_at  TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days'),
    accepted_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_invites_token ON public.user_invites(token);
CREATE INDEX IF NOT EXISTS idx_user_invites_email ON public.user_invites(email);

CREATE TRIGGER set_user_invites_updated_at
    BEFORE UPDATE ON public.user_invites
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.user_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_invites_admin ON public.user_invites
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 3. NICHOS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.nichos (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        TEXT NOT NULL,
    nome        TEXT NOT NULL,
    descricao   TEXT NOT NULL DEFAULT '',
    icone       TEXT NOT NULL DEFAULT '',
    order_idx   INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_nichos_slug ON public.nichos(slug);
CREATE INDEX IF NOT EXISTS idx_nichos_order ON public.nichos(order_idx);

CREATE TRIGGER set_nichos_updated_at
    BEFORE UPDATE ON public.nichos
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.nichos ENABLE ROW LEVEL SECURITY;

CREATE POLICY nichos_public_read ON public.nichos
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY nichos_admin_all ON public.nichos
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 4. SERVICES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.services (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        TEXT NOT NULL,
    titulo      TEXT NOT NULL,
    resumo      TEXT NOT NULL DEFAULT '',
    descricao   TEXT NOT NULL DEFAULT '',
    icone       TEXT NOT NULL DEFAULT '',
    beneficios  TEXT[] NOT NULL DEFAULT '{}',
    cta_label   TEXT NOT NULL DEFAULT '',
    cta_url     TEXT NOT NULL DEFAULT '',
    featured    BOOLEAN NOT NULL DEFAULT false,
    order_idx   INT NOT NULL DEFAULT 0,
    published   BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_services_slug ON public.services(slug);
CREATE INDEX IF NOT EXISTS idx_services_published ON public.services(published, order_idx);

CREATE TRIGGER set_services_updated_at
    BEFORE UPDATE ON public.services
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

CREATE POLICY services_public_read ON public.services
    FOR SELECT TO anon, authenticated
    USING (published = true);

CREATE POLICY services_admin_all ON public.services
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 5. PROJECTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.projects (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        TEXT NOT NULL,
    titulo      TEXT NOT NULL,
    resumo      TEXT NOT NULL DEFAULT '',
    descricao   TEXT NOT NULL DEFAULT '',
    problema    TEXT NOT NULL DEFAULT '',
    solucao     TEXT NOT NULL DEFAULT '',
    resultado   TEXT NOT NULL DEFAULT '',
    cliente     TEXT NOT NULL DEFAULT '',
    ano         INT,
    nicho       TEXT NOT NULL DEFAULT '',
    tags        TEXT[] NOT NULL DEFAULT '{}',
    cover_url   TEXT NOT NULL DEFAULT '',
    gallery     TEXT[] NOT NULL DEFAULT '{}',
    featured    BOOLEAN NOT NULL DEFAULT false,
    published   BOOLEAN NOT NULL DEFAULT false,
    order_idx   INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_projects_slug ON public.projects(slug);
CREATE INDEX IF NOT EXISTS idx_projects_published ON public.projects(published, order_idx);
CREATE INDEX IF NOT EXISTS idx_projects_featured ON public.projects(featured) WHERE featured = true;
CREATE INDEX IF NOT EXISTS idx_projects_nicho ON public.projects(nicho);

CREATE TRIGGER set_projects_updated_at
    BEFORE UPDATE ON public.projects
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY projects_public_read ON public.projects
    FOR SELECT TO anon, authenticated
    USING (published = true);

CREATE POLICY projects_admin_all ON public.projects
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 6. PROJECT TECHNOLOGIES (composite PK)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.project_technologies (
    project_id  UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    tech_name   TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, tech_name)
);

CREATE INDEX IF NOT EXISTS idx_project_technologies_project ON public.project_technologies(project_id);

CREATE TRIGGER set_project_technologies_updated_at
    BEFORE UPDATE ON public.project_technologies
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.project_technologies ENABLE ROW LEVEL SECURITY;

CREATE POLICY project_technologies_public_read ON public.project_technologies
    FOR SELECT TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.projects p
            WHERE p.id = project_id AND p.published = true
        )
    );

CREATE POLICY project_technologies_admin_all ON public.project_technologies
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 7. TESTIMONIALS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.testimonials (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    autor_nome      TEXT NOT NULL,
    autor_cargo     TEXT NOT NULL DEFAULT '',
    autor_empresa   TEXT NOT NULL DEFAULT '',
    autor_avatar_url TEXT NOT NULL DEFAULT '',
    depoimento      TEXT NOT NULL,
    rating          INT NOT NULL DEFAULT 5 CHECK (rating >= 1 AND rating <= 5),
    project_id      UUID REFERENCES public.projects(id) ON DELETE SET NULL,
    published       BOOLEAN NOT NULL DEFAULT false,
    order_idx       INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_testimonials_published ON public.testimonials(published, order_idx);
CREATE INDEX IF NOT EXISTS idx_testimonials_project ON public.testimonials(project_id);

CREATE TRIGGER set_testimonials_updated_at
    BEFORE UPDATE ON public.testimonials
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.testimonials ENABLE ROW LEVEL SECURITY;

CREATE POLICY testimonials_public_read ON public.testimonials
    FOR SELECT TO anon, authenticated
    USING (published = true);

CREATE POLICY testimonials_admin_all ON public.testimonials
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 8. BLOG CATEGORIES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.blog_categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        TEXT NOT NULL,
    nome        TEXT NOT NULL,
    descricao   TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_blog_categories_slug ON public.blog_categories(slug);

CREATE TRIGGER set_blog_categories_updated_at
    BEFORE UPDATE ON public.blog_categories
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.blog_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY blog_categories_public_read ON public.blog_categories
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY blog_categories_admin_all ON public.blog_categories
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 9. BLOG POSTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.blog_posts (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug             TEXT NOT NULL,
    titulo           TEXT NOT NULL,
    resumo           TEXT NOT NULL DEFAULT '',
    conteudo_json    JSONB,
    conteudo_html    TEXT NOT NULL DEFAULT '',
    cover_url        TEXT NOT NULL DEFAULT '',
    autor_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    categoria_id     UUID REFERENCES public.blog_categories(id) ON DELETE SET NULL,
    tags             TEXT[] NOT NULL DEFAULT '{}',
    reading_time     INT NOT NULL DEFAULT 0,
    seo_title        TEXT NOT NULL DEFAULT '',
    seo_description  TEXT NOT NULL DEFAULT '',
    og_image         TEXT NOT NULL DEFAULT '',
    published_at     TIMESTAMPTZ,
    status           TEXT NOT NULL DEFAULT 'rascunho'
                     CHECK (status IN ('rascunho', 'publicado', 'agendado')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_blog_posts_slug ON public.blog_posts(slug);
CREATE INDEX IF NOT EXISTS idx_blog_posts_autor ON public.blog_posts(autor_id);
CREATE INDEX IF NOT EXISTS idx_blog_posts_categoria ON public.blog_posts(categoria_id);
CREATE INDEX IF NOT EXISTS idx_blog_posts_status ON public.blog_posts(status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_blog_posts_published ON public.blog_posts(published_at DESC)
    WHERE status = 'publicado';

CREATE TRIGGER set_blog_posts_updated_at
    BEFORE UPDATE ON public.blog_posts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.blog_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY blog_posts_public_read ON public.blog_posts
    FOR SELECT TO anon, authenticated
    USING (status = 'publicado');

CREATE POLICY blog_posts_admin_all ON public.blog_posts
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 10. BANNERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.banners (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo      TEXT NOT NULL,
    subtitulo   TEXT NOT NULL DEFAULT '',
    imagem_url  TEXT NOT NULL DEFAULT '',
    cta_label   TEXT NOT NULL DEFAULT '',
    cta_url     TEXT NOT NULL DEFAULT '',
    posicao     TEXT NOT NULL DEFAULT 'home',
    ativo       BOOLEAN NOT NULL DEFAULT true,
    inicio_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    fim_at      TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_banners_ativo ON public.banners(ativo, posicao);
CREATE INDEX IF NOT EXISTS idx_banners_schedule ON public.banners(inicio_at, fim_at)
    WHERE ativo = true;

CREATE TRIGGER set_banners_updated_at
    BEFORE UPDATE ON public.banners
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY banners_public_read ON public.banners
    FOR SELECT TO anon, authenticated
    USING (ativo = true);

CREATE POLICY banners_admin_all ON public.banners
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 11. FAQS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.faqs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pergunta    TEXT NOT NULL,
    resposta    TEXT NOT NULL,
    categoria   TEXT NOT NULL DEFAULT '',
    order_idx   INT NOT NULL DEFAULT 0,
    published   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_faqs_published ON public.faqs(published, order_idx);
CREATE INDEX IF NOT EXISTS idx_faqs_categoria ON public.faqs(categoria);

CREATE TRIGGER set_faqs_updated_at
    BEFORE UPDATE ON public.faqs
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.faqs ENABLE ROW LEVEL SECURITY;

CREATE POLICY faqs_public_read ON public.faqs
    FOR SELECT TO anon, authenticated
    USING (published = true);

CREATE POLICY faqs_admin_all ON public.faqs
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 12. LEADS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.leads (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome                TEXT NOT NULL DEFAULT '',
    email               TEXT NOT NULL DEFAULT '',
    whatsapp            TEXT NOT NULL DEFAULT '',
    empresa             TEXT NOT NULL DEFAULT '',
    cargo               TEXT NOT NULL DEFAULT '',
    mensagem            TEXT NOT NULL DEFAULT '',
    tipo_servico        TEXT NOT NULL DEFAULT '',
    orcamento_estimado  TEXT NOT NULL DEFAULT '',
    prazo               TEXT NOT NULL DEFAULT '',
    fonte               TEXT NOT NULL DEFAULT '',
    utm_source          TEXT NOT NULL DEFAULT '',
    utm_medium          TEXT NOT NULL DEFAULT '',
    utm_campaign        TEXT NOT NULL DEFAULT '',
    utm_term            TEXT NOT NULL DEFAULT '',
    utm_content         TEXT NOT NULL DEFAULT '',
    ip                  TEXT NOT NULL DEFAULT '',
    user_agent          TEXT NOT NULL DEFAULT '',
    geo_pais            TEXT NOT NULL DEFAULT '',
    geo_estado          TEXT NOT NULL DEFAULT '',
    geo_cidade          TEXT NOT NULL DEFAULT '',
    status              TEXT NOT NULL DEFAULT 'novo'
                        CHECK (status IN ('novo', 'qualificado', 'em_atendimento', 'ganho', 'perdido')),
    owner_id            UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    score               INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_email ON public.leads(email);
CREATE INDEX IF NOT EXISTS idx_leads_owner ON public.leads(owner_id);
CREATE INDEX IF NOT EXISTS idx_leads_created ON public.leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_score ON public.leads(score DESC);

CREATE TRIGGER set_leads_updated_at
    BEFORE UPDATE ON public.leads
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

CREATE POLICY leads_admin_all ON public.leads
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Allow anon INSERT for contact forms
CREATE POLICY leads_anon_insert ON public.leads
    FOR INSERT TO anon
    WITH CHECK (true);

-- ============================================================================
-- 13. LEAD EVENTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.lead_events (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id      UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    tipo         TEXT NOT NULL,
    payload_json JSONB,
    ator_tipo    TEXT NOT NULL CHECK (ator_tipo IN ('sistema', 'admin', 'bot', 'cliente')),
    ator_id      UUID,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lead_events_lead ON public.lead_events(lead_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lead_events_tipo ON public.lead_events(tipo);

CREATE TRIGGER set_lead_events_updated_at
    BEFORE UPDATE ON public.lead_events
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.lead_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY lead_events_admin_all ON public.lead_events
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 14. CAMPAIGNS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.campaigns (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome            TEXT NOT NULL,
    utm_source      TEXT NOT NULL DEFAULT '',
    utm_medium      TEXT NOT NULL DEFAULT '',
    utm_campaign    TEXT NOT NULL DEFAULT '',
    ativa           BOOLEAN NOT NULL DEFAULT true,
    inicio          TIMESTAMPTZ NOT NULL DEFAULT now(),
    fim             TIMESTAMPTZ,
    custo_estimado  NUMERIC NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_campaigns_ativa ON public.campaigns(ativa);
CREATE INDEX IF NOT EXISTS idx_campaigns_utm ON public.campaigns(utm_source, utm_medium, utm_campaign);

CREATE TRIGGER set_campaigns_updated_at
    BEFORE UPDATE ON public.campaigns
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

CREATE POLICY campaigns_admin_all ON public.campaigns
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 15. MEDIA ASSETS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.media_assets (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    storage_path  TEXT NOT NULL,
    url           TEXT NOT NULL,
    mime          TEXT NOT NULL DEFAULT '',
    tamanho       BIGINT NOT NULL DEFAULT 0,
    largura       INT,
    altura        INT,
    alt_text      TEXT NOT NULL DEFAULT '',
    tags          TEXT[] NOT NULL DEFAULT '{}',
    uploaded_by   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_media_assets_uploaded_by ON public.media_assets(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_media_assets_mime ON public.media_assets(mime);

CREATE TRIGGER set_media_assets_updated_at
    BEFORE UPDATE ON public.media_assets
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.media_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY media_assets_admin_all ON public.media_assets
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Public read for serving images
CREATE POLICY media_assets_public_read ON public.media_assets
    FOR SELECT TO anon, authenticated
    USING (true);

-- ============================================================================
-- 16. WHATSAPP INSTANCES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.whatsapp_instances (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome                     TEXT NOT NULL,
    numero                   TEXT NOT NULL DEFAULT '',
    instance_name_evolution  TEXT NOT NULL,
    status                   TEXT NOT NULL DEFAULT 'desconectado',
    qrcode_url               TEXT NOT NULL DEFAULT '',
    ativa                    BOOLEAN NOT NULL DEFAULT true,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_whatsapp_instances_evolution
    ON public.whatsapp_instances(instance_name_evolution);

CREATE TRIGGER set_whatsapp_instances_updated_at
    BEFORE UPDATE ON public.whatsapp_instances
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.whatsapp_instances ENABLE ROW LEVEL SECURITY;

CREATE POLICY whatsapp_instances_admin_all ON public.whatsapp_instances
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 17. WHATSAPP MESSAGES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.whatsapp_messages (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id            UUID NOT NULL REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE,
    lead_id                UUID REFERENCES public.leads(id) ON DELETE SET NULL,
    direcao                TEXT NOT NULL CHECK (direcao IN ('in', 'out')),
    conteudo               TEXT NOT NULL DEFAULT '',
    tipo                   TEXT NOT NULL DEFAULT 'text',
    message_id_evolution   TEXT NOT NULL,
    status                 TEXT NOT NULL DEFAULT 'enviado',
    erro                   TEXT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_whatsapp_messages_evolution_id
    ON public.whatsapp_messages(message_id_evolution);
CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_instance ON public.whatsapp_messages(instance_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_lead ON public.whatsapp_messages(lead_id);

CREATE TRIGGER set_whatsapp_messages_updated_at
    BEFORE UPDATE ON public.whatsapp_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.whatsapp_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY whatsapp_messages_admin_all ON public.whatsapp_messages
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 18. WHATSAPP STATUS POSTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.whatsapp_status_posts (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id      UUID NOT NULL REFERENCES public.whatsapp_instances(id) ON DELETE CASCADE,
    midia_url        TEXT NOT NULL DEFAULT '',
    legenda          TEXT NOT NULL DEFAULT '',
    agendado_para    TIMESTAMPTZ,
    publicado_em     TIMESTAMPTZ,
    status           TEXT NOT NULL DEFAULT 'pendente'
                     CHECK (status IN ('pendente', 'publicando', 'publicado', 'erro')),
    payload_response JSONB,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_status_posts_instance
    ON public.whatsapp_status_posts(instance_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_whatsapp_status_posts_status
    ON public.whatsapp_status_posts(status);
CREATE INDEX IF NOT EXISTS idx_whatsapp_status_posts_agendado
    ON public.whatsapp_status_posts(agendado_para)
    WHERE status = 'pendente';

CREATE TRIGGER set_whatsapp_status_posts_updated_at
    BEFORE UPDATE ON public.whatsapp_status_posts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.whatsapp_status_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY whatsapp_status_posts_admin_all ON public.whatsapp_status_posts
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 19. INSTAGRAM ACCOUNTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.instagram_accounts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome              TEXT NOT NULL,
    ig_business_id    TEXT NOT NULL DEFAULT '',
    page_id           TEXT NOT NULL DEFAULT '',
    access_token_enc  TEXT NOT NULL DEFAULT '',
    expires_at        TIMESTAMPTZ,
    ativa             BOOLEAN NOT NULL DEFAULT true,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER set_instagram_accounts_updated_at
    BEFORE UPDATE ON public.instagram_accounts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.instagram_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY instagram_accounts_admin_all ON public.instagram_accounts
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 20. INSTAGRAM POSTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.instagram_posts (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id       UUID NOT NULL REFERENCES public.instagram_accounts(id) ON DELETE CASCADE,
    tipo             TEXT NOT NULL DEFAULT 'feed'
                     CHECK (tipo IN ('feed', 'reel', 'story')),
    midia_urls       TEXT[] NOT NULL DEFAULT '{}',
    legenda          TEXT NOT NULL DEFAULT '',
    agendado_para    TIMESTAMPTZ,
    publicado_em     TIMESTAMPTZ,
    status           TEXT NOT NULL DEFAULT 'pendente',
    ig_post_id       TEXT,
    payload_response JSONB,
    erro             TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_instagram_posts_account
    ON public.instagram_posts(account_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_instagram_posts_status ON public.instagram_posts(status);
CREATE INDEX IF NOT EXISTS idx_instagram_posts_agendado
    ON public.instagram_posts(agendado_para)
    WHERE status = 'pendente';

CREATE TRIGGER set_instagram_posts_updated_at
    BEFORE UPDATE ON public.instagram_posts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.instagram_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY instagram_posts_admin_all ON public.instagram_posts
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 21. VISITOR SESSIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.visitor_sessions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anon_id      TEXT NOT NULL DEFAULT '',
    ip_hash      TEXT NOT NULL DEFAULT '',
    user_agent   TEXT NOT NULL DEFAULT '',
    device       TEXT NOT NULL DEFAULT '',
    os           TEXT NOT NULL DEFAULT '',
    browser      TEXT NOT NULL DEFAULT '',
    geo_pais     TEXT NOT NULL DEFAULT '',
    geo_estado   TEXT NOT NULL DEFAULT '',
    geo_cidade   TEXT NOT NULL DEFAULT '',
    referrer     TEXT NOT NULL DEFAULT '',
    utm_source   TEXT NOT NULL DEFAULT '',
    utm_medium   TEXT NOT NULL DEFAULT '',
    utm_campaign TEXT NOT NULL DEFAULT '',
    utm_term     TEXT NOT NULL DEFAULT '',
    utm_content  TEXT NOT NULL DEFAULT '',
    landing_page TEXT NOT NULL DEFAULT '',
    started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at     TIMESTAMPTZ,
    total_pages  INT NOT NULL DEFAULT 0,
    total_events INT NOT NULL DEFAULT 0,
    converted    BOOLEAN NOT NULL DEFAULT false,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visitor_sessions_anon ON public.visitor_sessions(anon_id);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_started ON public.visitor_sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_converted ON public.visitor_sessions(converted)
    WHERE converted = true;

CREATE TRIGGER set_visitor_sessions_updated_at
    BEFORE UPDATE ON public.visitor_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.visitor_sessions ENABLE ROW LEVEL SECURITY;

-- Anon can INSERT to create sessions from the frontend tracker
CREATE POLICY visitor_sessions_anon_insert ON public.visitor_sessions
    FOR INSERT TO anon
    WITH CHECK (true);

CREATE POLICY visitor_sessions_admin_all ON public.visitor_sessions
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 22. PAGE VIEWS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.page_views (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id    UUID NOT NULL REFERENCES public.visitor_sessions(id) ON DELETE CASCADE,
    path          TEXT NOT NULL DEFAULT '',
    title         TEXT NOT NULL DEFAULT '',
    scroll_depth  INT NOT NULL DEFAULT 0,
    time_on_page  INT NOT NULL DEFAULT 0,  -- seconds
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_page_views_session ON public.page_views(session_id);
CREATE INDEX IF NOT EXISTS idx_page_views_path ON public.page_views(path);
CREATE INDEX IF NOT EXISTS idx_page_views_created ON public.page_views(created_at DESC);

CREATE TRIGGER set_page_views_updated_at
    BEFORE UPDATE ON public.page_views
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.page_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY page_views_anon_insert ON public.page_views
    FOR INSERT TO anon
    WITH CHECK (true);

CREATE POLICY page_views_admin_all ON public.page_views
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 23. EVENTS (analytics)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.events (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id   UUID NOT NULL REFERENCES public.visitor_sessions(id) ON DELETE CASCADE,
    tipo         TEXT NOT NULL,
    payload_json JSONB,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_session ON public.events(session_id);
CREATE INDEX IF NOT EXISTS idx_events_tipo ON public.events(tipo, created_at DESC);

CREATE TRIGGER set_events_updated_at
    BEFORE UPDATE ON public.events
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

CREATE POLICY events_anon_insert ON public.events
    FOR INSERT TO anon
    WITH CHECK (true);

CREATE POLICY events_admin_all ON public.events
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 24. CONSENT LOGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.consent_logs (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anon_id          TEXT NOT NULL DEFAULT '',
    lead_id          UUID REFERENCES public.leads(id) ON DELETE SET NULL,
    ip_hash          TEXT NOT NULL DEFAULT '',
    escopo           TEXT NOT NULL
                     CHECK (escopo IN ('analytics', 'push', 'geo', 'marketing', 'necessarios')),
    granted          BOOLEAN NOT NULL,
    versao_politica  TEXT NOT NULL DEFAULT '',
    user_agent       TEXT NOT NULL DEFAULT '',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_consent_logs_anon ON public.consent_logs(anon_id);
CREATE INDEX IF NOT EXISTS idx_consent_logs_lead ON public.consent_logs(lead_id);

CREATE TRIGGER set_consent_logs_updated_at
    BEFORE UPDATE ON public.consent_logs
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.consent_logs ENABLE ROW LEVEL SECURITY;

-- Anon can INSERT consent records from the cookie banner
CREATE POLICY consent_logs_anon_insert ON public.consent_logs
    FOR INSERT TO anon
    WITH CHECK (true);

CREATE POLICY consent_logs_admin_all ON public.consent_logs
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 25. PUSH SUBSCRIBERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.push_subscribers (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anon_id       TEXT NOT NULL DEFAULT '',
    lead_id       UUID REFERENCES public.leads(id) ON DELETE SET NULL,
    endpoint      TEXT NOT NULL,
    p256dh        TEXT NOT NULL DEFAULT '',
    auth_key      TEXT NOT NULL DEFAULT '',
    ativo         BOOLEAN NOT NULL DEFAULT true,
    last_seen_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_push_subscribers_endpoint ON public.push_subscribers(endpoint);
CREATE INDEX IF NOT EXISTS idx_push_subscribers_anon ON public.push_subscribers(anon_id);
CREATE INDEX IF NOT EXISTS idx_push_subscribers_lead ON public.push_subscribers(lead_id);

CREATE TRIGGER set_push_subscribers_updated_at
    BEFORE UPDATE ON public.push_subscribers
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.push_subscribers ENABLE ROW LEVEL SECURITY;

-- Anon can INSERT to register for push notifications
CREATE POLICY push_subscribers_anon_insert ON public.push_subscribers
    FOR INSERT TO anon
    WITH CHECK (true);

CREATE POLICY push_subscribers_admin_all ON public.push_subscribers
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 26. NOTIFICATIONS SENT
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.notifications_sent (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscriber_id  UUID NOT NULL REFERENCES public.push_subscribers(id) ON DELETE CASCADE,
    titulo         TEXT NOT NULL,
    corpo          TEXT NOT NULL DEFAULT '',
    url            TEXT NOT NULL DEFAULT '',
    payload_json   JSONB,
    status         TEXT NOT NULL DEFAULT 'enviado',
    sent_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    clicked_at     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_sent_subscriber
    ON public.notifications_sent(subscriber_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_sent_status ON public.notifications_sent(status);

CREATE TRIGGER set_notifications_sent_updated_at
    BEFORE UPDATE ON public.notifications_sent
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.notifications_sent ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_sent_admin_all ON public.notifications_sent
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 27. INTEGRATIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.integrations (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome          TEXT NOT NULL,
    config_json   JSONB NOT NULL DEFAULT '{}',
    secret_ref    TEXT NOT NULL DEFAULT '',
    ativa         BOOLEAN NOT NULL DEFAULT true,
    last_check_at TIMESTAMPTZ,
    last_status   TEXT NOT NULL DEFAULT '',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_integrations_nome ON public.integrations(nome);

CREATE TRIGGER set_integrations_updated_at
    BEFORE UPDATE ON public.integrations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.integrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY integrations_admin_all ON public.integrations
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 28. AUDIT LOGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ator_id     UUID,
    ator_tipo   TEXT NOT NULL DEFAULT '',
    acao        TEXT NOT NULL,
    entidade    TEXT NOT NULL DEFAULT '',
    entidade_id UUID,
    diff_json   JSONB,
    ip          TEXT NOT NULL DEFAULT '',
    user_agent  TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_ator ON public.audit_logs(ator_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entidade ON public.audit_logs(entidade, entidade_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at DESC);

CREATE TRIGGER set_audit_logs_updated_at
    BEFORE UPDATE ON public.audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can read audit logs
CREATE POLICY audit_logs_admin_all ON public.audit_logs
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 29. JOB RUNS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.job_runs (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inngest_event_id  TEXT NOT NULL DEFAULT '',
    funcao            TEXT NOT NULL,
    payload           JSONB,
    status            TEXT NOT NULL DEFAULT 'pendente',
    erro              TEXT,
    started_at        TIMESTAMPTZ,
    finished_at       TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_job_runs_status ON public.job_runs(status);
CREATE INDEX IF NOT EXISTS idx_job_runs_funcao ON public.job_runs(funcao, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_job_runs_inngest ON public.job_runs(inngest_event_id);

CREATE TRIGGER set_job_runs_updated_at
    BEFORE UPDATE ON public.job_runs
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.job_runs ENABLE ROW LEVEL SECURITY;

-- Only admins can read job runs
CREATE POLICY job_runs_admin_all ON public.job_runs
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 30. SITE SETTINGS (single-row)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.site_settings (
    id          INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    config      JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER set_site_settings_updated_at
    BEFORE UPDATE ON public.site_settings
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;

-- Public can read site settings (theme, SEO defaults, etc.)
CREATE POLICY site_settings_public_read ON public.site_settings
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY site_settings_admin_all ON public.site_settings
    FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Seed the single row so it always exists
INSERT INTO public.site_settings (id, config)
VALUES (1, '{}')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
