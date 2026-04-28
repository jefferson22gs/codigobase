# Código Base

> Plataforma SaaS + site institucional para captação de leads, portfólio profissional e automação comercial via WhatsApp e Instagram.

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/jefferson22gs/codigobase)

## 🚀 Stack

- **Framework**: Next.js 16 (App Router) + React 19
- **Linguagem**: TypeScript (strict mode)
- **Estilo**: Tailwind CSS 4 + shadcn/ui
- **Animações**: Framer Motion
- **Banco**: Supabase (Postgres + Auth + Storage + RLS)
- **Jobs**: Inngest (workflows assíncronos)
- **E-mail**: Resend
- **WhatsApp**: Evolution API
- **Instagram**: Graph API (estrutura preparada)
- **Push**: Web Push API (VAPID)
- **Deploy**: Vercel

## 🛠️ Setup Local

### 1. Clonar e instalar

```bash
git clone https://github.com/jefferson22gs/codigobase.git
cd codigobase/codigo-base
pnpm install
```

### 2. Configurar variáveis de ambiente

```bash
cp .env.example .env.local
```

Preencha todas as variáveis em `.env.local` (Supabase, Evolution API, Resend, Inngest, VAPID).

### 3. Criar banco Supabase

1. Crie um projeto em [supabase.com](https://supabase.com)
2. Abra o SQL Editor
3. Cole todo o conteúdo de `supabase/migrations/001_initial_schema.sql`
4. Execute (cria 30 tabelas + RLS policies)

### 4. Rodar dev server

```bash
pnpm dev
```

Acesse [http://localhost:3000](http://localhost:3000)

## 🚢 Deploy

### Vercel (recomendado)

1. Importe o repo no [Vercel](https://vercel.com)
2. Root Directory: `codigo-base`
3. Adicione todas as variáveis de ambiente
4. Deploy

### Configurar domínio

1. Vercel → Settings → Domains → Add `codigobase.com.br`
2. Adicione os registros DNS fornecidos no Registro.br

## 📊 Banco de Dados (30 tabelas)

- **Identidade**: profiles, user_invites
- **Conteúdo**: projects, services, testimonials, blog_posts, banners, faqs, nichos
- **CRM**: leads, lead_events, campaigns
- **WhatsApp**: whatsapp_instances, whatsapp_messages, whatsapp_status_posts
- **Instagram**: instagram_accounts, instagram_posts
- **Analytics**: visitor_sessions, page_views, events
- **LGPD**: consent_logs, push_subscribers, notifications_sent

## 🎨 Design System

### Cores

```css
--brand-cyan-500: #06B6D4      /* Primary */
--accent-orange-500: #F97316   /* CTA */
--bg-base: #07090F             /* Surface */
```

### Tipografia

- **Display**: Space Grotesk (headings)
- **Body**: Inter (texto)
- **Mono**: JetBrains Mono (código)

## 🤝 Contato

- **Site**: [codigobase.com.br](https://codigobase.com.br)
- **Instagram**: [@codigo.base](https://instagram.com/codigo.base)
- **E-mail**: contato@codigobase.com.br

---

Desenvolvido com ❤️ por Jefferson
