// flow.jsx — Phone + tablet mockups showing START → nagrywanie → QR

function FlowSection() {
  return (
    <section id="flow" style={{
      background: '#0F172A', color: '#fff', padding: '120px 24px',
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{
        position: 'absolute', top: '30%', left: '50%', transform: 'translate(-50%, -50%)',
        width: 1000, height: 600, borderRadius: '50%',
        background: 'radial-gradient(ellipse, rgba(79,70,229,0.15) 0%, rgba(79,70,229,0) 60%)',
        pointerEvents: 'none',
      }} />

      <div style={{ maxWidth: 1200, margin: '0 auto', position: 'relative' }}>
        <div style={{ marginBottom: 80, maxWidth: 720 }}>
          <Pill dark>Jak to działa</Pill>
          <h2 style={{
            fontFamily: 'Inter, system-ui', fontSize: 'clamp(28px, 4vw, 48px)',
            fontWeight: 700, lineHeight: 1.1, letterSpacing: '-0.025em',
            margin: '20px 0 20px', color: '#fff', textWrap: 'balance',
          }}>
            Od startu eventu do filmu w telefonie gościa w <em style={{
              fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
              fontWeight: 400, color: '#FB923C',
            }}>trzech krokach</em>.
          </h2>
          <p style={{
            fontFamily: 'Inter, system-ui', fontSize: 17, lineHeight: 1.6,
            color: 'rgba(255,255,255,0.65)', margin: 0, textWrap: 'pretty',
          }}>
            Tablet trzyma obsługa. Film trafia na telefon gościa. Bez rejestracji, bez logowań.
          </p>
        </div>

        {/* Step rail */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
          gap: 48, alignItems: 'start',
        }}>
          <FlowStep
            n="01"
            title="Ekran START na tablecie"
            caption="Obsługa wybiera event, apka ładuje ramki i muzykę przypisane do tego wesela."
            visual={<TabletStartMock />}
          />
          <FlowStep
            n="02"
            title="Nagrywanie 360°"
            caption="Gość na platformie, kamera obraca się, podgląd na tablecie. 8 sekund, bez opcji &quot;ups, jeszcze raz&quot; — albo i z taką opcją."
            visual={<PhoneRecordingMock />}
          />
          <FlowStep
            n="03"
            title="QR i film w kieszeni"
            caption="Gość skanuje QR, dostaje film w swoim brandingu — twoim brandingu. Zero logowań, zero aplikacji do pobrania."
            visual={<PhoneQRMock />}
          />
        </div>
      </div>
    </section>
  );
}

function FlowStep({ n, title, caption, visual }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 24 }}>
      {/* device */}
      <div style={{
        height: 500, display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative', width: '100%',
      }}>
        {visual}
      </div>
      {/* caption */}
      <div style={{ textAlign: 'left', maxWidth: 340, width: '100%' }}>
        <div style={{
          fontFamily: 'JetBrains Mono, ui-monospace, monospace', fontSize: 12,
          color: 'rgba(251,146,60,0.8)', letterSpacing: '0.1em', marginBottom: 10,
        }}>KROK {n}</div>
        <h3 style={{
          fontFamily: 'Inter, system-ui', fontSize: 20, fontWeight: 600,
          letterSpacing: '-0.02em', color: '#fff', margin: '0 0 8px',
          textWrap: 'balance',
        }}>{title}</h3>
        <p style={{
          fontFamily: 'Inter, system-ui', fontSize: 14, lineHeight: 1.55,
          color: 'rgba(255,255,255,0.6)', margin: 0, textWrap: 'pretty',
        }}>{caption}</p>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Mock 1 — Tablet START screen (landscape iPad-style frame)
// ─────────────────────────────────────────────────────────────
function TabletStartMock() {
  return (
    <div style={{
      width: 340, height: 240, borderRadius: 24,
      background: '#000', padding: 12, boxSizing: 'border-box',
      boxShadow: '0 30px 80px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.05)',
      transform: 'rotate(-2deg)',
    }}>
      <div style={{
        width: '100%', height: '100%', borderRadius: 16, overflow: 'hidden',
        background: `linear-gradient(135deg, #1E1B4B 0%, #0F172A 100%)`,
        position: 'relative', display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', padding: 20,
      }}>
        {/* bg pattern */}
        <div style={{
          position: 'absolute', inset: 0, opacity: 0.3,
          backgroundImage: 'radial-gradient(circle, rgba(249,115,22,0.4) 0%, transparent 50%)',
          backgroundSize: '180px 180px',
          backgroundPosition: 'center',
        }} />
        {/* event info */}
        <div style={{
          position: 'absolute', top: 16, left: 20, right: 20,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          fontFamily: 'Inter, system-ui', fontSize: 10, color: 'rgba(255,255,255,0.7)',
        }}>
          <span>● LIVE · Wesele Ani &amp; Marka</span>
          <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>21:47</span>
        </div>

        {/* big button */}
        <div style={{
          position: 'relative', zIndex: 1,
          width: 140, height: 140, borderRadius: '50%',
          background: `linear-gradient(135deg, ${ORANGE} 0%, #FB923C 100%)`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          flexDirection: 'column', gap: 4,
          boxShadow: '0 20px 40px rgba(249,115,22,0.4), inset 0 2px 0 rgba(255,255,255,0.2)',
        }}>
          <div style={{
            fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
            fontSize: 36, color: '#fff', fontWeight: 400, lineHeight: 1,
          }}>start</div>
          <div style={{
            fontFamily: 'Inter, system-ui', fontSize: 10, color: 'rgba(255,255,255,0.85)',
            letterSpacing: '0.1em', textTransform: 'uppercase',
          }}>dotknij aby nagrać</div>
        </div>

        {/* bottom branding */}
        <div style={{
          position: 'absolute', bottom: 14, left: 20, right: 20,
          display: 'flex', justifyContent: 'space-between',
          fontFamily: 'Inter, system-ui', fontSize: 9,
          color: 'rgba(255,255,255,0.4)',
        }}>
          <span>Akces 360 · twoja fotobudka</span>
          <span>ramka: rustykalna_03</span>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Mock 2 — Phone: recording in progress (using IOSDevice)
// ─────────────────────────────────────────────────────────────
function PhoneRecordingMock() {
  return (
    <div style={{
      transform: 'scale(0.46) rotate(3deg)',
      transformOrigin: 'center center',
    }}>
      <IOSDevice width={402} height={874} dark>
        <div style={{
          position: 'relative', height: '100%',
          background: 'linear-gradient(180deg, #1E293B 0%, #0F172A 100%)',
          display: 'flex', flexDirection: 'column',
        }}>
          {/* top bar */}
          <div style={{
            position: 'absolute', top: 80, left: 24, right: 24,
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          }}>
            <div style={{
              padding: '8px 14px', borderRadius: 999,
              background: 'rgba(239,68,68,0.2)',
              border: '1px solid rgba(239,68,68,0.4)',
              fontFamily: 'Inter, system-ui', fontSize: 14, fontWeight: 600,
              color: '#FCA5A5', display: 'flex', alignItems: 'center', gap: 8,
            }}>
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#EF4444' }} />
              REC · 0:03
            </div>
            <div style={{
              padding: '8px 14px', borderRadius: 999,
              background: 'rgba(255,255,255,0.08)',
              border: '1px solid rgba(255,255,255,0.15)',
              fontFamily: 'Inter, system-ui', fontSize: 14, color: '#fff',
            }}>×</div>
          </div>

          {/* camera circle */}
          <div style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
            position: 'relative',
          }}>
            <div style={{
              width: 260, height: 260, borderRadius: '50%',
              border: '2px dashed rgba(249,115,22,0.4)',
              position: 'relative',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {/* progress ring */}
              <svg width="280" height="280" viewBox="0 0 280 280" style={{ position: 'absolute', transform: 'rotate(-90deg)' }}>
                <circle cx="140" cy="140" r="130" fill="none"
                  stroke={ORANGE} strokeWidth="4" strokeLinecap="round"
                  strokeDasharray={`${2 * Math.PI * 130 * 0.38} ${2 * Math.PI * 130}`}
                />
              </svg>
              <div style={{
                width: 220, height: 220, borderRadius: '50%',
                background: 'radial-gradient(circle, rgba(79,70,229,0.3) 0%, rgba(15,23,42,0.8) 70%)',
                border: '1px solid rgba(255,255,255,0.1)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexDirection: 'column', gap: 8,
              }}>
                <div style={{
                  fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
                  fontSize: 40, color: 'rgba(255,255,255,0.9)', fontWeight: 400,
                }}>stój</div>
                <div style={{
                  fontFamily: 'Inter, system-ui', fontSize: 12,
                  color: 'rgba(255,255,255,0.5)',
                }}>platforma się obraca</div>
              </div>
            </div>
          </div>

          {/* bottom meta */}
          <div style={{
            padding: '20px 24px 60px',
            fontFamily: 'Inter, system-ui', fontSize: 12,
            color: 'rgba(255,255,255,0.5)', textAlign: 'center',
          }}>
            <div style={{ marginBottom: 6 }}>Muzyka: Przez twe oczy zielone</div>
            <div style={{
              fontFamily: 'JetBrains Mono, monospace', fontSize: 10,
              color: 'rgba(255,255,255,0.3)',
            }}>ramka_rustykalna_03 · 360° · 1080p</div>
          </div>
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Mock 3 — Phone: QR code screen
// ─────────────────────────────────────────────────────────────
function PhoneQRMock() {
  return (
    <div style={{
      transform: 'scale(0.46) rotate(-3deg)',
      transformOrigin: 'center center',
    }}>
      <IOSDevice width={402} height={874} dark={false}>
        <div style={{
          height: '100%',
          background: '#FAFAF7',
          display: 'flex', flexDirection: 'column',
          padding: '80px 32px 40px', boxSizing: 'border-box',
        }}>
          <div style={{
            fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
            fontSize: 32, color: '#0F172A', fontWeight: 400, lineHeight: 1.1,
            marginTop: 20, marginBottom: 8, textWrap: 'balance',
          }}>Twój film<br/>jest gotowy.</div>
          <div style={{
            fontFamily: 'Inter, system-ui', fontSize: 15, color: '#64748B',
            marginBottom: 32,
          }}>Zeskanuj kod. Bez rejestracji, bez apki.</div>

          {/* QR code — stylized */}
          <div style={{
            width: 260, height: 260, margin: '0 auto',
            background: '#fff', borderRadius: 16, padding: 16,
            boxSizing: 'border-box', boxShadow: '0 8px 24px rgba(15,23,42,0.08)',
            border: '1px solid #E8E6E0',
            position: 'relative',
          }}>
            <QRPattern />
            {/* centered logo */}
            <div style={{
              position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
              width: 48, height: 48, borderRadius: 8,
              background: `linear-gradient(135deg, ${ORANGE} 0%, #FB923C 100%)`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
              fontSize: 26, color: '#fff',
              border: '3px solid #fff',
            }}>a</div>
          </div>

          <div style={{
            marginTop: 32, textAlign: 'center',
            fontFamily: 'Inter, system-ui', fontSize: 13, color: '#475569',
          }}>
            Wesele Ani &amp; Marka · 22.06.2026
            <div style={{
              marginTop: 4, fontFamily: 'JetBrains Mono, monospace', fontSize: 11,
              color: '#94A3B8',
            }}>film/akces360/6d9f12ae</div>
          </div>

          <div style={{ flex: 1 }} />

          {/* brand footer */}
          <div style={{
            textAlign: 'center',
            fontFamily: 'Inter, system-ui', fontSize: 11,
            color: '#94A3B8',
          }}>
            obsługiwane przez <strong style={{ color: '#475569' }}>Akces 360</strong>
          </div>
        </div>
      </IOSDevice>
    </div>
  );
}

// Fake QR pattern — 21×21 grid
function QRPattern() {
  // Deterministic pseudo-random pattern
  const size = 21;
  const cells = [];
  const seed = 1337;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const n = Math.sin(x * 12.9898 + y * 78.233 + seed) * 43758.5453;
      const on = (n - Math.floor(n)) > 0.48;
      cells.push({ x, y, on });
    }
  }
  // Force finder squares at corners (3 of them)
  const isFinder = (x, y) => {
    const inBox = (bx, by) => x >= bx && x < bx + 7 && y >= by && y < by + 7;
    return inBox(0, 0) || inBox(size - 7, 0) || inBox(0, size - 7);
  };
  const isFinderDot = (x, y) => {
    const inDot = (bx, by) => x >= bx + 2 && x < bx + 5 && y >= by + 2 && y < by + 5;
    const inRing = (bx, by) => (x === bx || x === bx + 6) && y >= by && y <= by + 6
      || (y === by || y === by + 6) && x >= bx && x <= bx + 6;
    if (inDot(0, 0) || inDot(size - 7, 0) || inDot(0, size - 7)) return 'dot';
    if (inRing(0, 0) || inRing(size - 7, 0) || inRing(0, size - 7)) return 'ring';
    return null;
  };
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: `repeat(${size}, 1fr)`, gap: 0,
      width: '100%', height: '100%',
    }}>
      {cells.map(({ x, y, on }) => {
        const fnd = isFinderDot(x, y);
        let bg = 'transparent';
        if (fnd === 'ring' || fnd === 'dot') bg = '#0F172A';
        else if (isFinder(x, y)) bg = 'transparent';
        else if (on) bg = '#0F172A';
        return (
          <div key={`${x}-${y}`} style={{
            aspectRatio: '1', background: bg,
          }} />
        );
      })}
    </div>
  );
}

Object.assign(window, { FlowSection });
