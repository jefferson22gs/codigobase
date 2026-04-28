// TODO: Add Supabase auth guard

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen flex">
      {/* Sidebar placeholder */}
      <aside className="w-64 bg-card border-r border-border p-6">
        <div className="text-sm text-muted-foreground">Admin Sidebar</div>
        {/* TODO: Build full admin sidebar with navigation */}
      </aside>

      {/* Main content area */}
      <main className="flex-1 p-6">{children}</main>
    </div>
  );
}
