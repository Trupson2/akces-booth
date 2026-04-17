// closing.jsx — Pricing, Founder, Signup, Footer

function PricingSection() {
  return (
    <section id="cena" style={{
      background: '#FAFAF7', color: '#0F172A', padding: '120px 24px',
      borderTop: '1px solid #E8E6E0',
    }}>
      <div style={{ maxWidth: 900, margin: '0 auto' }}>
        <div style={{ marginBottom: 48, maxWidth: 720 }}>
          <Pill>Cennik · podgląd</Pill>
          <h2 style={{
            fontFamily: 'Inter, system-ui', fontSize: 'clamp(28px, 4vw, 48px)',
            fontWeight: 700, lineHeight: 1.1, letterSpacing: '-0.025em',
            margin: '20px 0 20px', color: '#0F172A', textWrap: 'balance',
          }}>
            Jedna cena, <em style={{
              fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
              fontWeight: 400,
            }}>wszystko w środku</em>.
          </h2>
          <p style={{
            fontFamily: 'Inter, system-ui', fontSize: 17, lineHeight: 1.6,
            color: '#475569', margin: 0, textWrap: 'pretty',
          }}>
            Robimy walidację cen z pierwszymi klientami. Ta stawka to nasz startowy benchmark.
          </p>
        </div>

        <div style={{
          padding: 40, borderRadius: 24,
          background: `linear-gradient(180deg, #fff 0%, #FAFAF7 100%)`,
          border: '1px solid #E8E6E0',
          boxShadow: '0 8px 32px rgba(15,23,42,0.04)',
          display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 40,
        }} className="pricing-card">
          <div>
            <div style={{
              fontFamily: 'JetBrains Mono, monospace', fontSize: 12,
              color: INDIGO, letterSpacing: '0.08em', textTransform: 'uppercase',
              marginBottom: 16,
            }}>Early Access · rok 1</div>
            <div style={{
              display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 8,
            }}>
              <span style={{
                fontFamily: 'Inter, system-ui', fontSize: 18, color: '#64748B',
              }}>od</span>
              <span style={{
                fontFamily: 'Inter, system-ui', fontSize: 72, fontWeight: 700,
                letterSpacing: '-0.03em', lineHeight: 1, color: '#0F172A',
              }}>49</span>
              <span style={{
                fontFamily: 'Inter, system-ui', fontSize: 20, fontWeight: 500,
                color: '#475569',
              }}>PLN / mc</span>
            </div>
            <div style={{
              fontFamily: 'Inter, system-ui', fontSize: 14, color: '#64748B',
              marginBottom: 24, fontStyle: 'italic',
            }}>
              * cena orientacyjna, finalna do ustalenia po walidacji z pierwszymi klientami
            </div>
            <div style={{
              padding: 16, borderRadius: 12,
              background: 'rgba(249,115,22,0.06)',
              border: '1px solid rgba(249,115,22,0.2)',
              fontFamily: 'Inter, system-ui', fontSize: 13, lineHeight: 1.5,
              color: '#9A3412',
            }}>
              <strong>Early birdsi</strong> dostają tę cenę zamrożoną na 12 miesięcy. I&nbsp;głos w tym, co budujemy.
            </div>
          </div>
          <div>
            <div style={{
              fontFamily: 'Inter, system-ui', fontSize: 13, fontWeight: 500,
              color: '#334155', marginBottom: 16, letterSpacing: '-0.01em',
            }}>W cenie, bez addonów:</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {[
                'Własne logo i branding na każdym filmie',
                'Bez limitu eventów w miesiącu',
                'Bez limitu filmów na gościa',
                'Ramki AI generowane pod event',
                'Biblioteka polskich tracków',
                'QR i web-galeria dla gości',
                'Support PL · telefon, WhatsApp, email',
              ].map((f, i) => (
                <div key={i} style={{
                  display: 'flex', alignItems: 'flex-start', gap: 10,
                  fontFamily: 'Inter, system-ui', fontSize: 14, lineHeight: 1.45,
                  color: '#334155',
                }}>
                  <span style={{
                    flexShrink: 0, marginTop: 5,
                    color: '#16A34A',
                  }}>{Icon.check('#16A34A')}</span>
                  {f}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// FOUNDER — Adrian / Akces 360
// ─────────────────────────────────────────────────────────────
function FounderSection() {
  return (
    <section id="o-nas" style={{
      background: '#F5F3ED', color: '#0F172A', padding: '120px 24px',
      borderTop: '1px solid #E8E6E0',
    }}>
      <div style={{ maxWidth: 900, margin: '0 auto' }}>
        <div style={{
          display: 'grid', gridTemplateColumns: '240px 1fr', gap: 48,
          alignItems: 'start',
        }} className="founder-grid">
          {/* portrait placeholder */}
          <div>
            <div style={{
              width: 200, height: 260, borderRadius: 16,
              background: `linear-gradient(135deg, #1E293B 0%, #4F46E5 100%)`,
              position: 'relative', overflow: 'hidden',
              border: '1px solid #E8E6E0',
            }}>
              <div style={{
                position: 'absolute', inset: 0,
                background: 'repeating-linear-gradient(45deg, rgba(255,255,255,0.04), rgba(255,255,255,0.04) 10px, transparent 10px, transparent 20px)',
              }} />
              <div style={{
                position: 'absolute', bottom: 12, left: 12, right: 12,
                padding: '8px 10px', background: 'rgba(15,23,42,0.6)',
                backdropFilter: 'blur(8px)', borderRadius: 8,
                fontFamily: 'JetBrains Mono, monospace', fontSize: 10,
                color: 'rgba(255,255,255,0.85)', letterSpacing: '0.05em',
              }}>zdjęcie Adriana ↗</div>
            </div>
            <div style={{
              marginTop: 16, fontFamily: 'Inter, system-ui',
              fontSize: 14, fontWeight: 600, color: '#0F172A',
            }}>Adrian · założyciel, deweloper, fotobudkarz</div>
            <div style={{
              fontFamily: 'Inter, system-ui', fontSize: 13,
              color: '#64748B',
            }}>Akces 360 · Mieszkowice</div>
          </div>

          {/* story */}
          <div>
            <Pill>O nas</Pill>
            <h2 style={{
              fontFamily: 'Inter, system-ui', fontSize: 'clamp(24px, 3vw, 36px)',
              fontWeight: 700, lineHeight: 1.15, letterSpacing: '-0.025em',
              margin: '20px 0 24px', color: '#0F172A', textWrap: 'balance',
            }}>
              „Kupiłem fotobudkę, odpaliłem apkę i wiedziałem,
              że muszę napisać <em style={{
                fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
                fontWeight: 400,
              }}>lepszą.</em>”
            </h2>
            <div style={{
              fontFamily: 'Inter, system-ui', fontSize: 16, lineHeight: 1.65,
              color: '#334155', textWrap: 'pretty',
              display: 'flex', flexDirection: 'column', gap: 16,
            }}>
              <p style={{ margin: 0 }}>
                Jestem Adrian. W październiku 2025 kupiłem sprzęt do fotobudek 360°
                i zarejestrowałem Akces 360 — jednoosobowa działalność, Mieszkowice,
                Zachodniopomorskie. Równolegle prowadzę Akces Hub, softwarowy projekt
                do obsługi palet zwrotnych w handlu.
              </p>
              <p style={{ margin: 0 }}>
                Apkę ChackTok testowałem pół roku zanim postanowiłem wziąć sprawy
                w swoje ręce. Logo producenta na każdym filmie klienta. Support po
                angielsku w strefie czasowej Los Angeles. Abonament w dolarach
                z VAT-em. Pomyślałem, że musi być prostszy sposób — szczególnie
                dla polskiego rynku.
              </p>
              <p style={{ margin: 0 }}>
                Buduję Akces Booth solo, z Claude Code jako partnerem do kodu.
                Nie jestem startupem szukającym rynku. Jestem
                dewelopero-fotobudkarzem, który robi narzędzie dla siebie —
                a przy okazji udostępni je innym, którzy mają tę samą frustrację.
                Pierwsze eventy robię osobiście w sezonie weselnym 2026. Early
                access dla fotobudkarzy startuje tego samego lata.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// Final CTA signup
// ─────────────────────────────────────────────────────────────
function SignupSection({ socialCount = 10 }) {
  return (
    <section id="zapis" style={{
      background: '#0B1220', color: '#fff', padding: '120px 24px',
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{
        position: 'absolute', inset: 0,
        backgroundImage: 'radial-gradient(circle at 50% 50%, rgba(249,115,22,0.15) 0%, rgba(249,115,22,0) 50%)',
        pointerEvents: 'none',
      }} />
      <div style={{
        position: 'absolute', inset: 0,
        backgroundImage: 'linear-gradient(rgba(255,255,255,0.025) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.025) 1px, transparent 1px)',
        backgroundSize: '48px 48px',
        maskImage: 'radial-gradient(circle at 50% 50%, #000 20%, transparent 70%)',
        WebkitMaskImage: 'radial-gradient(circle at 50% 50%, #000 20%, transparent 70%)',
      }} />

      <div style={{
        position: 'relative', maxWidth: 640, margin: '0 auto', textAlign: 'center',
      }}>
        <Pill dark accent>Early access · zamknięta grupa</Pill>
        <h2 style={{
          fontFamily: 'Inter, system-ui', fontSize: 'clamp(32px, 5vw, 56px)',
          fontWeight: 700, lineHeight: 1.1, letterSpacing: '-0.03em',
          margin: '24px 0 20px', color: '#fff', textWrap: 'balance',
        }}>
          Dołącz, zanim ruszamy <em style={{
            fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
            fontWeight: 400, color: '#FB923C',
          }}>na dobre</em>.
        </h2>
        <p style={{
          fontFamily: 'Inter, system-ui', fontSize: 17, lineHeight: 1.55,
          color: 'rgba(255,255,255,0.7)', margin: '0 auto 40px',
          textWrap: 'pretty', maxWidth: 500,
        }}>
          Pierwsi zapisani dostają cenę startową zamrożoną na 12 miesięcy
          i bezpośredni kontakt do zespołu. Bez spamu, bez newslettera co czwartek.
        </p>
        <EmailSignup large dark />

        {/* social proof — honest variant */}
        <div style={{
          marginTop: 40, padding: '20px 24px', borderRadius: 12,
          background: 'rgba(255,255,255,0.03)',
          border: '1px solid rgba(255,255,255,0.08)',
          display: 'inline-flex', alignItems: 'center', gap: 12,
          fontFamily: 'Inter, system-ui', fontSize: 15, lineHeight: 1.5,
          color: 'rgba(255,255,255,0.75)', textAlign: 'left',
        }}>
          <span style={{
            width: 8, height: 8, borderRadius: '50%', background: ORANGE,
            boxShadow: `0 0 10px ${ORANGE}`, flexShrink: 0,
          }} />
          <span>Lista dopiero się otwiera — <strong style={{ color: '#fff', fontWeight: 600 }}>bądź pierwszy.</strong></span>
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────
function Footer() {
  return (
    <footer style={{
      background: '#050814', color: 'rgba(255,255,255,0.5)',
      padding: '48px 24px 40px',
      borderTop: '1px solid rgba(255,255,255,0.06)',
    }}>
      <div style={{
        maxWidth: 1100, margin: '0 auto',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        flexWrap: 'wrap', gap: 20,
        fontFamily: 'Inter, system-ui', fontSize: 13,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            width: 24, height: 24, borderRadius: 6,
            background: `linear-gradient(135deg, ${ORANGE} 0%, #FB923C 100%)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: 'Instrument Serif, serif', fontSize: 14,
            color: '#fff', fontStyle: 'italic',
          }}>a</div>
          <span>Akces Booth · projekt Akces 360 · Adrian (JDG) · Mieszkowice</span>
        </div>
        <div style={{ display: 'flex', gap: 20 }}>
          <a href="mailto:adrian@akces360.pl" style={{ color: 'inherit', textDecoration: 'none' }}>Kontakt</a>
          <a href="/polityka-prywatnosci" style={{ color: 'inherit', textDecoration: 'none' }}>Polityka prywatności</a>
          <a href="#faq" style={{ color: 'inherit', textDecoration: 'none' }}>FAQ</a>
        </div>
      </div>
    </footer>
  );
}

Object.assign(window, { PricingSection, FounderSection, SignupSection, Footer });
