// app.jsx — root App + ReactDOM.createRoot
//
// Must be loaded AFTER sections/flow/closing/faq (in that order) bo Babel
// Standalone nie zawsze gwarantuje kolejnosc wykonania miedzy inline a src.
// Wyjmujac App do osobnego pliku src wymuszamy load order via HTML.

function App() {
  const [tweaks, setTweaks] = React.useState(window.TWEAKS || { heroVariant: 'safe' });

  React.useEffect(() => {
    window.__setTweaks = (patch) => setTweaks(t => ({ ...t, ...patch }));
  }, []);

  return (
    <div>
      <Hero variant={tweaks.heroVariant} socialCount={tweaks.socialCount} />
      <ProblemSection />
      <SolutionSection />
      <FlowSection />
      <PricingSection />
      <FounderSection />
      <FaqSection />
      <SignupSection socialCount={tweaks.socialCount} />
      <Footer />
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
