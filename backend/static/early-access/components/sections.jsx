// sections.jsx — Hero, Problem, Solution, Pricing, Founder, Signup

const ORANGE = '#F97316';
const ORANGE_HOVER = '#EA580C';
const INDIGO = '#4F46E5';

// ─────────────────────────────────────────────────────────────
// Tiny inline icon set (stroke-based, monoline)
// ─────────────────────────────────────────────────────────────
const Icon = {
  arrow: (c = 'currentColor') => (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M3 8h10m0 0L9 4m4 4l-4 4" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  check: (c = 'currentColor') => (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M2.5 7.5l3 3 6-7" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  x: (c = 'currentColor') => (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M3 3l8 8M11 3l-8 8" stroke={c} strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  ),
  spark: (c = 'currentColor') => (
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
      <path d="M10 2v4M10 14v4M2 10h4M14 10h4M4.3 4.3l2.8 2.8M12.9 12.9l2.8 2.8M4.3 15.7l2.8-2.8M12.9 7.1l2.8-2.8" stroke={c} strokeWidth="1.5" strokeLinecap="round"/>
    </svg>
  ),
};

// ─────────────────────────────────────────────────────────────
// Badge / "coming soon" pill used across sections
// ─────────────────────────────────────────────────────────────
function Pill({ children, dark = false, accent = false }) {
  const bg = accent ? 'rgba(249,115,22,0.12)' : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(15,23,42,0.05)');
  const border = accent ? 'rgba(249,115,22,0.3)' : (dark ? 'rgba(255,255,255,0.1)' : 'rgba(15,23,42,0.08)');
  const color = accent ? '#FB923C' : (dark ? 'rgba(255,255,255,0.75)' : '#334155');
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 8,
      padding: '6px 12px', borderRadius: 999,
      background: bg, border: `1px solid ${border}`, color,
      fontFamily: 'Inter, system-ui', fontSize: 13, fontWeight: 500,
      letterSpacing: '-0.01em', whiteSpace: 'nowrap',
    }}>
      {accent && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%', background: ORANGE,
          boxShadow: `0 0 8px ${ORANGE}`,
        }} />
      )}
      {children}
    </span>
  );
}

// ─────────────────────────────────────────────────────────────
// Email input (used in hero + footer signup)
// ─────────────────────────────────────────────────────────────
function EmailSignup({ large = false, onSubmit, dark = true, id = 'email-1' }) {
  const [email, setEmail] = React.useState('');
  const [submitted, setSubmitted] = React.useState(false);
  const [sending, setSending] = React.useState(false);
  const [checked, setChecked] = React.useState(true);
  const inputH = large ? 56 : 48;
  const fs = large ? 16 : 15;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email.includes('@') || sending) return;
    setSending(true);
    try {
      await fetch('/api/early-access/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email.trim().toLowerCase(),
          consent: checked,
          hero_variant: (window.TWEAKS && window.TWEAKS.heroVariant) || 'safe',
        }),
      });
    } catch (err) {
      // Nie blokujemy UI jesli siec zawiedzie - pokazujemy thanks i tak,
      // a Ty zobaczysz w logach ze nie doszlo. Lepsze niz fail message.
      console.error('[EmailSignup] POST failed', err);
    }
    setSending(false);
    setSubmitted(true);
    onSubmit && onSubmit(email);
  };

  if (submitted) {
    return (
      <div style={{
        padding: large ? '20px 24px' : '16px 20px',
        background: dark ? 'rgba(34,197,94,0.1)' : 'rgba(34,197,94,0.08)',
        border: `1px solid ${dark ? 'rgba(34,197,94,0.3)' : 'rgba(34,197,94,0.25)'}`,
        borderRadius: 12, display: 'flex', alignItems: 'center', gap: 12,
        fontFamily: 'Inter, system-ui', fontSize: fs,
        color: dark ? '#86EFAC' : '#15803D', fontWeight: 500,
      }}>
        <span style={{ fontSize: 20 }}>✓</span>
        Dzięki! Odezwiemy się jako pierwsi, gdy ruszamy.
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <input
          type="email"
          required
          placeholder="adres@email.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          style={{
            flex: '1 1 220px', minWidth: 0, height: inputH,
            padding: '0 18px', borderRadius: 12,
            background: dark ? 'rgba(255,255,255,0.04)' : '#fff',
            border: `1px solid ${dark ? 'rgba(255,255,255,0.12)' : 'rgba(15,23,42,0.12)'}`,
            color: dark ? '#fff' : '#0F172A',
            fontFamily: 'Inter, system-ui', fontSize: fs, fontWeight: 400,
            outline: 'none', transition: 'border-color 0.15s',
          }}
          onFocus={(e) => e.target.style.borderColor = ORANGE}
          onBlur={(e) => e.target.style.borderColor = dark ? 'rgba(255,255,255,0.12)' : 'rgba(15,23,42,0.12)'}
        />
        <button type="submit" disabled={sending} style={{
          height: inputH, padding: '0 24px', borderRadius: 12, border: 'none',
          background: ORANGE, color: '#fff',
          fontFamily: 'Inter, system-ui', fontSize: fs, fontWeight: 600,
          letterSpacing: '-0.01em', cursor: sending ? 'wait' : 'pointer',
          opacity: sending ? 0.7 : 1,
          display: 'inline-flex', alignItems: 'center', gap: 8,
          transition: 'background 0.15s, transform 0.1s, opacity 0.15s',
          boxShadow: '0 4px 12px rgba(249,115,22,0.3)',
        }}
          onMouseEnter={(e) => { if (!sending) e.currentTarget.style.background = ORANGE_HOVER; }}
          onMouseLeave={(e) => e.currentTarget.style.background = ORANGE}
        >
          {sending ? 'Zapisuję…' : <>Zapisz mnie {Icon.arrow('#fff')}</>}
        </button>
      </div>
      <label style={{
        display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer',
        fontFamily: 'Inter, system-ui', fontSize: 13,
        color: dark ? 'rgba(255,255,255,0.6)' : '#64748B',
      }}>
        <input
          type="checkbox" checked={checked}
          onChange={(e) => setChecked(e.target.checked)}
          style={{
            width: 16, height: 16, accentColor: ORANGE, cursor: 'pointer',
          }}
        />
        Chcę dostawać info o early access i dacie startu.
      </label>
      <div style={{
        fontFamily: 'Inter, system-ui', fontSize: 11, lineHeight: 1.5,
        color: dark ? 'rgba(255,255,255,0.4)' : '#94A3B8',
      }}>
        Twój email trafia tylko do nas (Akces 360, Mieszkowice, JDG).
        Zero newslettera co tydzień.
        Szczegóły w&nbsp;
        <a href="/polityka-prywatnosci" target="_blank" style={{
          color: dark ? 'rgba(255,255,255,0.7)' : '#475569',
          textDecoration: 'underline',
        }}>polityce prywatności</a>.
      </div>
    </form>
  );
}

// ─────────────────────────────────────────────────────────────
// HERO — dark, two copy variants
// ─────────────────────────────────────────────────────────────
function Hero({ variant = 'safe', socialCount = 10 }) {
  const copy = {
    safe: {
      headline: <>Polska fotobudka 360°<br/><em style={{ fontFamily: 'Instrument Serif, serif', fontStyle: 'italic', color: '#FB923C', fontWeight: 400 }}>bez</em> logo producenta<br/>na każdym filmie.</>,
      sub: 'Własny branding, tańsza subskrypcja, polski support. Aplikacja od fotobudkarzy dla fotobudkarzy.',
    },
    bold: {
      headline: <>Twoi klienci wychodzą z wesela<br/>z filmem, na którym widać<br/><em style={{ fontFamily: 'Instrument Serif, serif', fontStyle: 'italic', color: '#FB923C', fontWeight: 400 }}>cudze</em> logo.</>,
      sub: 'Pora to zmienić. Lokalna apka, własny branding, uczciwa cena. Budujemy ją teraz — dołącz do listy early access.',
    },
  };
  const c = copy[variant];

  return (
    <section style={{
      position: 'relative', background: '#0B1220', color: '#fff',
      padding: '0 0 120px', overflow: 'hidden',
    }}>
      {/* ambient glow */}
      <div style={{
        position: 'absolute', top: -200, left: '50%', transform: 'translateX(-50%)',
        width: 900, height: 900, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(79,70,229,0.25) 0%, rgba(79,70,229,0) 60%)',
        pointerEvents: 'none',
      }} />
      <div style={{
        position: 'absolute', bottom: -100, right: -200,
        width: 600, height: 600, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(249,115,22,0.12) 0%, rgba(249,115,22,0) 60%)',
        pointerEvents: 'none',
      }} />
      {/* grid texture */}
      <div style={{
        position: 'absolute', inset: 0,
        backgroundImage: 'linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px)',
        backgroundSize: '64px 64px',
        maskImage: 'radial-gradient(circle at 50% 0%, #000 30%, transparent 70%)',
        WebkitMaskImage: 'radial-gradient(circle at 50% 0%, #000 30%, transparent 70%)',
      }} />

      {/* nav */}
      <nav style={{
        position: 'relative', zIndex: 2,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        maxWidth: 1200, margin: '0 auto', padding: '24px 24px 0',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            width: 32, height: 32, borderRadius: 8,
            background: `linear-gradient(135deg, ${ORANGE} 0%, #FB923C 100%)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: 'Instrument Serif, serif', fontSize: 20, fontWeight: 400,
            color: '#fff', fontStyle: 'italic',
          }}>a</div>
          <div style={{
            fontFamily: 'Inter, system-ui', fontSize: 15, fontWeight: 600,
            letterSpacing: '-0.02em', color: '#fff',
          }}>
            Akces Booth
            <span style={{ marginLeft: 8, color: 'rgba(255,255,255,0.35)', fontWeight: 400 }}>
              by Akces 360
            </span>
          </div>
        </div>
        <div style={{
          display: 'flex', gap: 24, alignItems: 'center',
          fontFamily: 'Inter, system-ui', fontSize: 14,
          color: 'rgba(255,255,255,0.7)',
        }} className="nav-links">
          <a href="#problem" style={{ color: 'inherit', textDecoration: 'none' }}>Problem</a>
          <a href="#rozwiazanie" style={{ color: 'inherit', textDecoration: 'none' }}>Rozwiązanie</a>
          <a href="#cena" style={{ color: 'inherit', textDecoration: 'none' }}>Cena</a>
          <a href="#zapis" style={{
            padding: '8px 16px', borderRadius: 8,
            background: 'rgba(255,255,255,0.08)',
            border: '1px solid rgba(255,255,255,0.12)',
            color: '#fff', textDecoration: 'none', fontWeight: 500,
          }}>Early access</a>
        </div>
      </nav>

      {/* hero content */}
      <div style={{
        position: 'relative', zIndex: 2,
        maxWidth: 1100, margin: '0 auto', padding: '80px 24px 0',
        textAlign: 'center',
      }}>
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 28 }}>
          <Pill dark accent>W budowie · Pierwsze eventy lato 2026</Pill>
        </div>
        <h1 style={{
          fontFamily: 'Inter, system-ui', fontSize: 'clamp(36px, 6vw, 72px)',
          fontWeight: 700, lineHeight: 1.05, letterSpacing: '-0.03em',
          margin: '0 0 24px', color: '#fff',
          textWrap: 'balance',
        }}>{c.headline}</h1>
        <p style={{
          fontFamily: 'Inter, system-ui', fontSize: 'clamp(16px, 1.6vw, 20px)',
          fontWeight: 400, lineHeight: 1.5, letterSpacing: '-0.01em',
          color: 'rgba(255,255,255,0.7)', maxWidth: 620, margin: '0 auto 40px',
          textWrap: 'pretty',
        }}>{c.sub}</p>

        {/* signup */}
        <div style={{ maxWidth: 520, margin: '0 auto' }}>
          <EmailSignup large dark />
        </div>

        {/* social proof */}
        <div style={{
          marginTop: 28, display: 'flex', alignItems: 'center', justifyContent: 'center',
          gap: 12, fontFamily: 'Inter, system-ui', fontSize: 14,
          color: 'rgba(255,255,255,0.55)',
        }}>
          <span style={{
            width: 6, height: 6, borderRadius: '50%', background: ORANGE,
            boxShadow: `0 0 8px ${ORANGE}`,
          }} />
          <span>Lista dopiero się otwiera — <strong style={{ color: '#fff', fontWeight: 600 }}>bądź pierwszy.</strong></span>
        </div>

        {/* preview device mockup peek */}
        <div style={{ marginTop: 80, position: 'relative' }}>
          <HeroDevicePeek />
        </div>
      </div>
    </section>
  );
}

// Schematic fotobudka preview — placeholder visual in hero
function HeroDevicePeek() {
  return (
    <div style={{
      position: 'relative', maxWidth: 900, margin: '0 auto',
      aspectRatio: '16 / 9',
      background: 'linear-gradient(180deg, rgba(255,255,255,0.04) 0%, rgba(255,255,255,0.02) 100%)',
      border: '1px solid rgba(255,255,255,0.08)',
      borderRadius: 20, overflow: 'hidden',
      boxShadow: '0 40px 100px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.05)',
    }}>
      {/* faux toolbar */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '12px 16px', borderBottom: '1px solid rgba(255,255,255,0.06)',
      }}>
        <div style={{ width: 10, height: 10, borderRadius: '50%', background: '#FF5F57' }} />
        <div style={{ width: 10, height: 10, borderRadius: '50%', background: '#FEBC2E' }} />
        <div style={{ width: 10, height: 10, borderRadius: '50%', background: '#28C840' }} />
        <div style={{
          flex: 1, textAlign: 'center',
          fontFamily: 'Inter, system-ui', fontSize: 12, color: 'rgba(255,255,255,0.4)',
        }}>panel.akcesbooth.pl — event #2847 · Wesele Ani &amp; Marka</div>
      </div>

      {/* main content — split */}
      <div style={{
        display: 'grid', gridTemplateColumns: '260px 1fr', height: 'calc(100% - 42px)',
      }} className="hero-peek-grid">
        {/* sidebar */}
        <div style={{
          padding: 20, borderRight: '1px solid rgba(255,255,255,0.06)',
          display: 'flex', flexDirection: 'column', gap: 6,
        }}>
          {['Event', 'Ramki AI', 'Muzyka', 'Branding', 'Goście', 'Statystyki'].map((l, i) => (
            <div key={l} style={{
              padding: '8px 12px', borderRadius: 8, fontFamily: 'Inter, system-ui',
              fontSize: 13, color: i === 1 ? '#fff' : 'rgba(255,255,255,0.5)',
              background: i === 1 ? 'rgba(249,115,22,0.14)' : 'transparent',
              border: i === 1 ? '1px solid rgba(249,115,22,0.25)' : '1px solid transparent',
              display: 'flex', alignItems: 'center', gap: 8,
            }}>
              <div style={{
                width: 6, height: 6, borderRadius: '50%',
                background: i === 1 ? ORANGE : 'rgba(255,255,255,0.2)',
              }} />
              {l}
            </div>
          ))}
        </div>
        {/* right pane — frame grid placeholder */}
        <div style={{ padding: 24, overflow: 'hidden' }}>
          <div style={{
            fontFamily: 'Inter, system-ui', fontSize: 13, color: 'rgba(255,255,255,0.5)',
            marginBottom: 12,
          }}>Ramki wygenerowane dla tego eventu</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
            {[0,1,2,3,4,5,6,7].map(i => (
              <div key={i} style={{
                aspectRatio: '9 / 16', borderRadius: 8,
                background: i === 0
                  ? `linear-gradient(135deg, ${ORANGE} 0%, #FB923C 100%)`
                  : 'repeating-linear-gradient(45deg, rgba(255,255,255,0.04), rgba(255,255,255,0.04) 8px, rgba(255,255,255,0.02) 8px, rgba(255,255,255,0.02) 16px)',
                border: '1px solid rgba(255,255,255,0.08)',
                position: 'relative',
                display: 'flex', alignItems: 'flex-end', padding: 8,
              }}>
                <span style={{
                  fontFamily: 'JetBrains Mono, ui-monospace, monospace', fontSize: 9,
                  color: i === 0 ? 'rgba(255,255,255,0.85)' : 'rgba(255,255,255,0.35)',
                }}>ramka_{String(i+1).padStart(2,'0')}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// PROBLEM — dark continuation, 3 columns
// ─────────────────────────────────────────────────────────────
function ProblemSection() {
  const items = [
    {
      n: '01',
      title: 'Cudze logo na filmach twoich klientów',
      body: 'Wysyłasz panu młodemu filmik z wesela, a w rogu świeci logo zagranicznego dostawcy. To jego marka rośnie, nie twoja. Brak white-label w podstawowym planie.',
    },
    {
      n: '02',
      title: 'Support po angielsku, w strefie czasowej PST',
      body: 'Awaria w sobotę o 21:00, goście już przy budce. Ticket po angielsku, odpowiedź w poniedziałek rano. Dla wydarzenia to wieczność.',
    },
    {
      n: '03',
      title: 'Ponad 100 PLN za subskrypcję. Co miesiąc.',
      body: 'Płacisz w dolarach, z kursem, z VAT-em, z limitami eventów i filmów. Doliczając addony, wychodzi tyle, co kolejna budka w pół roku.',
    },
  ];

  return (
    <section id="problem" style={{
      background: '#0B1220', color: '#fff', padding: '120px 24px',
      borderTop: '1px solid rgba(255,255,255,0.05)',
    }}>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <div style={{ marginBottom: 64, maxWidth: 720 }}>
          <Pill dark>Problem</Pill>
          <h2 style={{
            fontFamily: 'Inter, system-ui', fontSize: 'clamp(28px, 4vw, 48px)',
            fontWeight: 700, lineHeight: 1.1, letterSpacing: '-0.025em',
            margin: '20px 0 20px', color: '#fff', textWrap: 'balance',
          }}>
            Zagraniczny soft buduje <em style={{
              fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
              fontWeight: 400, color: '#FB923C',
            }}>czyjąś</em> markę na twoich eventach.
          </h2>
          <p style={{
            fontFamily: 'Inter, system-ui', fontSize: 17, lineHeight: 1.6,
            color: 'rgba(255,255,255,0.65)', margin: 0, textWrap: 'pretty',
          }}>
            Przez pół roku testowałem trzy największe apki do fotobudek 360°. Te trzy rzeczy wracały w każdej z nich.
          </p>
        </div>

        <div style={{
          display: 'grid', gap: 16,
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
        }}>
          {items.map((it, i) => (
            <div key={i} style={{
              padding: 32, borderRadius: 16,
              background: 'rgba(255,255,255,0.02)',
              border: '1px solid rgba(255,255,255,0.08)',
              display: 'flex', flexDirection: 'column', gap: 16,
              position: 'relative', overflow: 'hidden',
            }}>
              <div style={{
                fontFamily: 'Instrument Serif, serif', fontSize: 48, fontStyle: 'italic',
                color: 'rgba(249,115,22,0.8)', lineHeight: 1, fontWeight: 400,
              }}>{it.n}</div>
              <h3 style={{
                fontFamily: 'Inter, system-ui', fontSize: 18, fontWeight: 600,
                letterSpacing: '-0.015em', margin: 0, color: '#fff',
                textWrap: 'balance',
              }}>{it.title}</h3>
              <p style={{
                fontFamily: 'Inter, system-ui', fontSize: 15, lineHeight: 1.55,
                color: 'rgba(255,255,255,0.6)', margin: 0, textWrap: 'pretty',
              }}>{it.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// SOLUTION — LIGHT section from here on
// ─────────────────────────────────────────────────────────────
function SolutionSection() {
  return (
    <section id="rozwiazanie" style={{
      background: '#FAFAF7', color: '#0F172A', padding: '120px 24px',
      borderTop: '1px solid #E8E6E0',
    }}>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <div style={{ marginBottom: 64, maxWidth: 720 }}>
          <Pill>Rozwiązanie</Pill>
          <h2 style={{
            fontFamily: 'Inter, system-ui', fontSize: 'clamp(28px, 4vw, 48px)',
            fontWeight: 700, lineHeight: 1.1, letterSpacing: '-0.025em',
            margin: '20px 0 20px', color: '#0F172A', textWrap: 'balance',
          }}>
            Zbudowane w Polsce, dla polskich <em style={{
              fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
              fontWeight: 400,
            }}>realiów eventowych</em>.
          </h2>
          <p style={{
            fontFamily: 'Inter, system-ui', fontSize: 17, lineHeight: 1.6,
            color: '#475569', margin: 0, textWrap: 'pretty',
          }}>
            Trzy rzeczy, które robimy inaczej niż duzi gracze.
          </p>
        </div>

        <div style={{
          display: 'grid', gap: 20,
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
        }}>
          <SolutionCard
            tag="AI"
            title="Ramki generowane per event"
            body="Wpisujesz: &quot;wesele rustykalne, suchar gipsowy, kolor butelkowa zieleń&quot;. Dostajesz 12 gotowych nakładek wideo z monogramem pary. Zero stockowych serduszek."
            visual={<FrameAIVisual />}
          />
          <SolutionCard
            tag="Audio"
            title="Polskie przeboje weselne"
            body="Licencjonowane tracki, które realnie lecą na polskich weselach — disco polo, biesiadne, weselne klasyki, chillout z mglistych lat. Nie generic royalty-free z YouTube."
            visual={<MusicVisual />}
          />
          <SolutionCard
            tag="Cena"
            title="Jedna subskrypcja, bez limitów"
            body="Bez &quot;do 5 eventów w miesiącu&quot;. Bez dopłat za white-label. Bez osobnej płatności za dostęp gościa. Robisz 20 wesel we wrzesień? Cena ta sama."
            visual={<PricingVisual />}
          />
        </div>
      </div>
    </section>
  );
}

function SolutionCard({ tag, title, body, visual }) {
  return (
    <div style={{
      padding: 28, borderRadius: 20, background: '#fff',
      border: '1px solid #E8E6E0',
      display: 'flex', flexDirection: 'column', gap: 20,
      boxShadow: '0 1px 3px rgba(15,23,42,0.04)',
    }}>
      <div style={{
        height: 160, borderRadius: 12, overflow: 'hidden',
        background: '#F5F3ED', position: 'relative',
      }}>{visual}</div>
      <div style={{
        display: 'inline-flex', alignSelf: 'flex-start', padding: '4px 10px',
        borderRadius: 6, background: 'rgba(79,70,229,0.08)',
        color: INDIGO, fontFamily: 'JetBrains Mono, ui-monospace, monospace',
        fontSize: 11, fontWeight: 500, letterSpacing: '0.05em', textTransform: 'uppercase',
      }}>{tag}</div>
      <h3 style={{
        fontFamily: 'Inter, system-ui', fontSize: 22, fontWeight: 600,
        letterSpacing: '-0.02em', lineHeight: 1.2, margin: 0,
        color: '#0F172A', textWrap: 'balance',
      }}>{title}</h3>
      <p style={{
        fontFamily: 'Inter, system-ui', fontSize: 15, lineHeight: 1.55,
        color: '#475569', margin: 0, textWrap: 'pretty',
      }}>{body}</p>
    </div>
  );
}

// Mini visuals (all placeholder-style, no stock imagery)
function FrameAIVisual() {
  return (
    <div style={{
      position: 'absolute', inset: 0, display: 'grid',
      gridTemplateColumns: 'repeat(4, 1fr)', gap: 6, padding: 16,
    }}>
      {[0,1,2,3,4,5,6,7].map(i => (
        <div key={i} style={{
          borderRadius: 4, aspectRatio: '9 / 16',
          background: i === 2
            ? `linear-gradient(135deg, ${ORANGE} 0%, #FB923C 100%)`
            : `repeating-linear-gradient(45deg, rgba(15,23,42,0.04), rgba(15,23,42,0.04) 4px, rgba(15,23,42,0.02) 4px, rgba(15,23,42,0.02) 8px)`,
          border: '1px solid rgba(15,23,42,0.06)',
          opacity: 1 - i * 0.08,
        }} />
      ))}
    </div>
  );
}
function MusicVisual() {
  return (
    <div style={{
      position: 'absolute', inset: 0, padding: 20,
      display: 'flex', flexDirection: 'column', gap: 8, justifyContent: 'center',
    }}>
      {[
        { t: 'Przez twe oczy zielone — klasyk', d: '03:42', active: true },
        { t: 'Maczo Man — disco wesele', d: '04:01' },
        { t: 'Jesteś szalona — biesiadna', d: '03:28' },
        { t: 'Chillout set · 2010s PL', d: '42:15' },
      ].map((tr, i) => (
        <div key={i} style={{
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '8px 12px', borderRadius: 8,
          background: tr.active ? 'rgba(249,115,22,0.08)' : 'transparent',
          border: `1px solid ${tr.active ? 'rgba(249,115,22,0.18)' : 'rgba(15,23,42,0.06)'}`,
        }}>
          <div style={{
            width: 22, height: 22, borderRadius: 4,
            background: tr.active ? ORANGE : 'rgba(15,23,42,0.1)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            {tr.active && (
              <div style={{ display: 'flex', gap: 1.5, alignItems: 'end', height: 10 }}>
                <div style={{ width: 2, height: '60%', background: '#fff' }} />
                <div style={{ width: 2, height: '100%', background: '#fff' }} />
                <div style={{ width: 2, height: '40%', background: '#fff' }} />
              </div>
            )}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{
              fontFamily: 'Inter, system-ui', fontSize: 11, fontWeight: 500,
              color: '#0F172A', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            }}>{tr.t}</div>
          </div>
          <span style={{
            fontFamily: 'JetBrains Mono, monospace', fontSize: 10, color: '#94A3B8',
          }}>{tr.d}</span>
        </div>
      ))}
    </div>
  );
}
function PricingVisual() {
  return (
    <div style={{
      position: 'absolute', inset: 0, padding: 20,
      display: 'flex', flexDirection: 'column', gap: 8, justifyContent: 'center',
    }}>
      {[
        { label: 'Eventy w miesiącu', value: '∞' },
        { label: 'Filmy / gość', value: '∞' },
        { label: 'Własne logo na wideo', value: '✓' },
        { label: 'Dostęp dla gości (QR)', value: '✓' },
        { label: 'Addon white-label', value: '—' },
      ].map((r, i) => (
        <div key={i} style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          paddingBottom: 8,
          borderBottom: i < 4 ? '1px dashed rgba(15,23,42,0.08)' : 'none',
          fontFamily: 'Inter, system-ui', fontSize: 12, color: '#334155',
        }}>
          <span>{r.label}</span>
          <span style={{
            fontFamily: r.value === '∞' ? 'Instrument Serif, serif' : 'inherit',
            fontSize: r.value === '∞' ? 20 : 14, fontStyle: r.value === '∞' ? 'italic' : 'normal',
            fontWeight: 600, color: r.value === '—' ? '#94A3B8' : '#0F172A',
          }}>{r.value}</span>
        </div>
      ))}
    </div>
  );
}

Object.assign(window, {
  Hero, ProblemSection, SolutionSection, EmailSignup, Pill, Icon,
  ORANGE, ORANGE_HOVER, INDIGO,
});
