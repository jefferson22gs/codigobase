import type { Metadata } from "next";
import { Space_Grotesk, Inter, JetBrains_Mono } from "next/font/google";
import { ThemeProvider } from "next-themes";
import { Toaster } from "sonner";
import "./globals.css";

const spaceGrotesk = Space_Grotesk({
  variable: "--font-heading",
  subsets: ["latin"],
  display: "swap",
});

const inter = Inter({
  variable: "--font-sans",
  subsets: ["latin"],
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://codigobase.com.br"),
  title: {
    template: "%s | Código Base",
    default: "Código Base — Software, Hardware e Automação",
  },
  description:
    "Transformamos ideias em soluções digitais que impulsionam negócios. Desenvolvimento de sites, sistemas, SaaS, apps mobile e automações inteligentes.",
  keywords: [
    "desenvolvimento web",
    "sistemas personalizados",
    "SaaS",
    "aplicativos mobile",
    "automação",
    "APIs",
    "software sob medida",
    "transformação digital",
  ],
  authors: [{ name: "Código Base" }],
  creator: "Código Base",
  openGraph: {
    type: "website",
    locale: "pt_BR",
    url: "https://codigobase.com.br",
    siteName: "Código Base",
    title: "Código Base — Software, Hardware e Automação",
    description:
      "Transformamos ideias em soluções digitais que impulsionam negócios.",
    images: [
      {
        url: "https://codigobase.com.br/og.png",
        width: 1200,
        height: 630,
        alt: "Código Base",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Código Base — Software, Hardware e Automação",
    description:
      "Transformamos ideias em soluções digitais que impulsionam negócios.",
    images: ["https://codigobase.com.br/og.png"],
  },
  robots: {
    index: true,
    follow: true,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="pt-BR"
      className={`dark ${spaceGrotesk.variable} ${inter.variable} ${jetbrainsMono.variable}`}
      suppressHydrationWarning
    >
      <body className="min-h-screen flex flex-col antialiased">
        <ThemeProvider
          attribute="class"
          defaultTheme="dark"
          disableTransitionOnChange
        >
          {children}
          <Toaster position="top-right" richColors />
        </ThemeProvider>
      </body>
    </html>
  );
}
