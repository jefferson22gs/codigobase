export default function HomePage() {
  return (
    <div className="min-h-[calc(100vh-4rem)] flex items-center justify-center">
      <div className="text-center space-y-4">
        <h1 className="text-4xl md:text-6xl font-heading font-bold">
          <span className="text-brand-cyan-400">Home</span>
          <span className="text-muted-foreground"> — </span>
          <span className="text-accent-orange-500">Em construção</span>
        </h1>
        <p className="text-lg text-muted-foreground max-w-md mx-auto">
          Estamos preparando algo incrível para você. Aguarde!
        </p>
      </div>
    </div>
  );
}
