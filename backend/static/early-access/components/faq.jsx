// faq.jsx — FAQ section (pytania kasujace obiekcje przed zapisem)
//
// Wstawione miedzy FounderSection a SignupSection. Plain accordion,
// details/summary semantics - bez zbednej biblioteki.

function FaqSection() {
  const items = [
    {
      q: 'Kiedy dokladnie startuje Akces Booth?',
      a: 'Pierwsze eventy robie osobiscie w sezonie weselnym 2026 (lipiec-sierpien). Early access dla innych fotobudkarzy otwieramy rownolegle - przewidywany start beta: sierpien 2026. Przy zapisie dostaniesz dokladna date mailem zanim podamy ja publicznie.',
    },
    {
      q: 'Ile to bedzie kosztowac?',
      a: 'Cena startowa: od 49 PLN/mc, zamrozona na 12 miesiecy dla early birds. To wersja orientacyjna - finalna cena wyjdzie po walidacji z pierwszymi klientami. Zero ukrytych addonow: bialy label, brak limitu eventow, ramki AI, muzyka, support PL - wszystko w tej cenie.',
    },
    {
      q: 'Czy musze kupowac nowa fotobudke?',
      a: 'Nie. Apka wspiera popularne modele fotobudek 360° ze sterowaniem BLE (m.in. ChackTok, 360 Controller, Snap360 compatible). Jesli masz inny sprzet - odezwij sie, dopiszemy protokol. Reversujemy je sami, wiec "zamkniety" soft producenta nie jest przeszkoda.',
    },
    {
      q: 'Co z moja obecna apka / subskrypcja?',
      a: 'Mozesz ja nadal uzywac rownolegle - my jestesmy alternatywa, nie zamiennikiem pod klucz. Przy migracji pomozemy eksportem eventow i kontaktow (o ile obecny provider to umozliwia). Zadnych lock-inow.',
    },
    {
      q: 'Jaki jest support? Co jesli cos padnie w sobote wieczorem?',
      a: 'Telefon, WhatsApp, email - po polsku, strefa czasowa Polski. Przy early access: bezposredni numer do mnie (Adrian). Skoro sam tez robie eventy, wiem jak wyglada panic w trakcie wesela o 22:30.',
    },
    {
      q: 'Czy moje dane sa bezpieczne?',
      a: 'Email z tego formularza idzie tylko do naszej bazy (SQLite na serwerze w Polsce, Akces 360). Nie sprzedajemy, nie udostepniamy, nie profilujemy. Wypisanie: jeden mail. Szczegoly w polityce prywatnosci pod formularzem.',
    },
    {
      q: 'Czemu ja ci mam wierzyc?',
      a: 'Bo nie mam nic do sprzedania az do Q3 2026. Landing jest oficjalnym zobowiazaniem - jesli nie dostarcze, widzisz to tutaj. Rownoleglie prowadze Akces Hub (soft do obslugi palet zwrotnych), co potwierdza ze potrafie dowozic produkty softwarowe.',
    },
    {
      q: 'Mozna sie z Toba spotkac / zadzwonic przed decyzja?',
      a: 'Tak. Early birds dostaja numer telefonu przy potwierdzeniu zapisu. Jesli masz pytania PRZED zapisem - napisz na adrian@akces360.pl, odpisuje w 24h.',
    },
  ];

  return (
    <section id="faq" style={{
      background: '#FAFAF7', color: '#0F172A', padding: '120px 24px',
      borderTop: '1px solid #E8E6E0',
    }}>
      <div style={{ maxWidth: 820, margin: '0 auto' }}>
        <div style={{ marginBottom: 48, maxWidth: 720 }}>
          <Pill>FAQ</Pill>
          <h2 style={{
            fontFamily: 'Inter, system-ui', fontSize: 'clamp(28px, 4vw, 44px)',
            fontWeight: 700, lineHeight: 1.15, letterSpacing: '-0.025em',
            margin: '20px 0 20px', color: '#0F172A', textWrap: 'balance',
          }}>
            Co chcesz wiedziec <em style={{
              fontFamily: 'Instrument Serif, serif', fontStyle: 'italic',
              fontWeight: 400,
            }}>zanim sie zapiszesz</em>.
          </h2>
          <p style={{
            fontFamily: 'Inter, system-ui', fontSize: 17, lineHeight: 1.6,
            color: '#475569', margin: 0, textWrap: 'pretty',
          }}>
            Pytania, ktore najczesciej wracaja w rozmowach z innymi fotobudkarzami.
          </p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          {items.map((it, i) => (
            <FaqItem key={i} q={it.q} a={it.a} />
          ))}
        </div>
      </div>
    </section>
  );
}

function FaqItem({ q, a }) {
  const [open, setOpen] = React.useState(false);
  return (
    <div style={{
      background: '#fff',
      border: '1px solid #E8E6E0',
      borderRadius: 12,
      overflow: 'hidden',
      transition: 'border-color 0.15s',
    }}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        style={{
          width: '100%', padding: '20px 24px', border: 'none', background: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          gap: 16, cursor: 'pointer', textAlign: 'left',
          fontFamily: 'Inter, system-ui', fontSize: 16, fontWeight: 600,
          letterSpacing: '-0.015em', color: '#0F172A',
        }}
      >
        <span style={{ flex: 1 }}>{q}</span>
        <span style={{
          width: 24, height: 24, borderRadius: '50%',
          background: open ? 'rgba(249,115,22,0.12)' : 'rgba(15,23,42,0.05)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          transition: 'all 0.2s', flexShrink: 0,
          color: open ? '#EA580C' : '#64748B',
        }}>
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none"
               style={{ transform: open ? 'rotate(45deg)' : 'rotate(0deg)', transition: 'transform 0.2s' }}>
            <path d="M6 2v8M2 6h8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
          </svg>
        </span>
      </button>
      {open && (
        <div style={{
          padding: '0 24px 20px',
          fontFamily: 'Inter, system-ui', fontSize: 15, lineHeight: 1.6,
          color: '#475569', textWrap: 'pretty',
        }}>
          {a}
        </div>
      )}
    </div>
  );
}

Object.assign(window, { FaqSection, FaqItem });
