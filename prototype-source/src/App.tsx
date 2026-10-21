import { useState, type FormEvent, type ReactNode } from "react"

type IconName = "home" | "search" | "plus" | "chat" | "user" | "ball" | "pin" | "calendar" | "clock" | "arrow" | "chevron" | "bell" | "close" | "check" | "filter" | "star" | "trophy" | "logout" | "menu" | "send" | "image" | "shield" | "map" | "flag" | "edit" | "trash"
function Icon({
  name,
  size = 20,
  className = "",
}: {
  name: IconName
  size?: number
  className?: string
}) {
  const paths: Record<IconName, ReactNode> = {
    home: (
      <>
        <path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z" />
      </>
    ),
    search: (
      <>
        <circle cx="10.5" cy="10.5" r="6.5" />
        <path d="m16 16 5 5" />
      </>
    ),
    plus: <path d="M12 5v14M5 12h14" />,
    chat: <path d="M21 11a8 8 0 0 1-8 8H7l-5 3 2-6a9 9 0 1 1 17-5Z" />,
    user: (
      <>
        <circle cx="12" cy="7" r="4" />
        <path d="M4 21v-2a8 8 0 0 1 16 0v2" />
      </>
    ),
    ball: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="m12 8 4 3-2 5h-4l-2-5zM12 8V3M16 11l5-2M14 16l3 4M10 16l-3 4M8 11 3 9" />
      </>
    ),
    pin: (
      <>
        <path d="M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 0 1 14 0Z" />
        <circle cx="12" cy="10" r="2.5" />
      </>
    ),
    calendar: (
      <>
        <rect x="3" y="5" width="18" height="16" rx="3" />
        <path d="M7 3v4M17 3v4M3 11h18M7 15h2M13 15h2" />
      </>
    ),
    clock: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </>
    ),
    arrow: <path d="M4 12h16m-6-6 6 6-6 6" />,
    chevron: <path d="m9 5 7 7-7 7" />,
    bell: (
      <>
        <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" />
      </>
    ),
    close: <path d="m6 6 12 12M6 18 18 6" />,
    check: <path d="m5 12 4 4L19 6" />,
    filter: (
      <>
        <path d="M4 7h16M4 17h16" />
        <circle cx="8" cy="7" r="2" fill="currentColor" />
        <circle cx="16" cy="17" r="2" fill="currentColor" />
      </>
    ),
    star: (
      <path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9z" />
    ),
    trophy: (
      <>
        <path d="M7 3h10v7a5 5 0 0 1-10 0ZM7 5H3v3a4 4 0 0 0 4 4m10-7h4v3a4 4 0 0 1-4 4M12 15v5M8 21h8" />
      </>
    ),
    logout: (
      <>
        <path d="M9 4H4v16h5M10 12h11m-4-4 4 4-4 4" />
      </>
    ),
    menu: <path d="M4 6h16M4 12h16M4 18h16" />,
    send: (
      <>
        <path d="m3 3 19 9-19 9 4-9zM7 12h15" />
      </>
    ),
    image: (
      <>
        <rect x="3" y="3" width="18" height="18" rx="3" />
        <circle cx="8" cy="8" r="2" />
        <path d="m3 17 5-5 4 4 4-6 5 7" />
      </>
    ),
    shield: (
      <>
        <path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6z" />
        <path d="m8 12 3 3 5-6" />
      </>
    ),
    map: (
      <>
        <path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2zM9 3v16M15 5v16" />
      </>
    ),
    flag: (
      <>
        <path d="M5 21V3c6-4 8 5 15 1v11c-7 4-9-5-15-1" />
      </>
    ),
    edit: (
      <>
        <path d="m16 3 5 5-12 12-6 1 1-6zM13 6l5 5" />
      </>
    ),
    trash: (
      <>
        <path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7" />
      </>
    ),
  }
  return (
    <svg
      width={size}
      height={size}
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  )
}
function Crest({
  team = "uniao",
  small = false,
}: {
  team?: string
  small?: boolean
}) {
  return (
    <div className={`crest crest-${team} ${small ? "small" : ""}`}>
      <span>
        {team === "uniao"
          ? "UFC"
          : team === "real"
            ? "RA"
            : team === "vila"
              ? "VILA"
              : team === "atletico"
                ? "AC"
                : "EC"}
      </span>
      <Icon name={team === "real" ? "trophy" : "ball"} size={small ? 15 : 23} />
      <small>
        {team === "uniao" ? "2015" : team === "real" ? "2010" : "2018"}
      </small>
    </div>
  )
}
function Button({
  children,
  onClick,
  variant = "primary",
  className = "",
  type = "button",
}: {
  children: ReactNode
  onClick?: () => void
  variant?: string
  className?: string
  type?: "button" | "submit"
}) {
  return (
    <button
      type={type}
      className={`btn btn-${variant} ${className}`}
      onClick={onClick}
    >
      {children}
    </button>
  )
}
interface FieldProps {
  label: string
  children: ReactNode
}
function Field({ label, children }: FieldProps) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  )
}

type Game = {
  id: number
  name: string
  crest: string
  sport: string
  category: string
  city: string
  date: string
  time: string
  place: string
  level: string
  distance: string
  home: string
}
const initialGames: Game[] = [
  {
    id: 1,
    name: "Real Amigos FC",
    crest: "real",
    sport: "Futebol",
    category: "Livre",
    city: "São Paulo, SP",
    date: "Sáb, 18 jul",
    time: "16:00",
    place: "Campo do Ibirapuera",
    level: "Intermediário",
    distance: "3,2 km",
    home: "Jogo em casa",
  },
  {
    id: 2,
    name: "Vila Nova Futsal",
    crest: "vila",
    sport: "Futsal",
    category: "Livre",
    city: "São Paulo, SP",
    date: "Dom, 19 jul",
    time: "10:00",
    place: "Quadra Vila Mariana",
    level: "Intermediário",
    distance: "4,8 km",
    home: "Casa ou fora",
  },
  {
    id: 3,
    name: "Atlético da Zona Sul",
    crest: "atletico",
    sport: "Futebol",
    category: "Sub-20",
    city: "São Paulo, SP",
    date: "Sáb, 18 jul",
    time: "09:00",
    place: "Campo Santo Amaro",
    level: "Avançado",
    distance: "6,1 km",
    home: "Jogo fora",
  },
  {
    id: 4,
    name: "Resenha Esporte Clube",
    crest: "resenha",
    sport: "Futebol",
    category: "Veterano",
    city: "São Paulo, SP",
    date: "Dom, 19 jul",
    time: "08:30",
    place: "Arena da Saúde",
    level: "Recreativo",
    distance: "7,5 km",
    home: "Casa ou fora",
  },
]
const navItems: {
  label: string
  page: string
  icon: IconName
  badge?: string
}[] = [
  { label: "Início", page: "home", icon: "home" },
  { label: "Buscar adversário", page: "search", icon: "search" },
  { label: "Anunciar jogo", page: "create", icon: "plus" },
  { label: "Conversas", page: "conversations", icon: "chat", badge: "2" },
  { label: "Meus jogos", page: "games", icon: "calendar" },
  { label: "Meus anúncios", page: "ads", icon: "flag" },
  { label: "Mapa de jogos", page: "map", icon: "map" },
]
const titles: Record<string, string> = {
  home: "Início",
  search: "Buscar adversário",
  create: "Anunciar jogo",
  conversations: "Conversas",
  chat: "Conversa",
  games: "Meus jogos",
  ads: "Meus anúncios",
  map: "Mapa de jogos",
  profile: "Perfil do time",
  notifications: "Notificações",
  details: "Detalhes do jogo",
  confirmed: "Partida confirmada",
  review: "Avaliar partida",
}

export default function App() {
  const [page, setPage] = useState("home")
  const [selected, setSelected] = useState(initialGames[0])
  const [sport, setSport] = useState("Todos")
  const [query, setQuery] = useState("")
  const [filters, setFilters] = useState(false)
  const [category, setCategory] = useState("Todas")
  const [level, setLevel] = useState("Todos")
  const [distance, setDistance] = useState("25")
  const [dateFilter, setDateFilter] = useState("")
  const [modal, setModal] = useState("")
  const [toast, setToast] = useState("")
  const [messages, setMessages] = useState([
    { text: "Olá! Temos interesse em jogar.", mine: true },
    { text: "Opa, João! Vocês conseguem jogar sábado às 16h?", mine: false },
    { text: "Sim, podemos. Vamos combinar!", mine: true },
  ])
  const [message, setMessage] = useState("")
  const [confirmed, setConfirmed] = useState(false)
  const [gameTab, setGameTab] = useState("Todos")
  const [ads, setAds] = useState<{
    title: string
    status: string
  }[]>([{ title: "União FC procura adversário", status: "Ativo" }])
  const [registerStep, setRegisterStep] = useState(1)
  const [rating, setRating] = useState<Record<string, number>>({})
  const [mobileMenu, setMobileMenu] = useState(false)
  const [userName, setUserName] = useState("João")
  const [teamName, setTeamName] = useState("União FC")
  const [editIndex, setEditIndex] = useState<number | null>(null)
  const go = (next: string) => {
    setPage(next)
    setMobileMenu(false)
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
  const notify = (text: string) => {
    setToast(text)
    window.setTimeout(() => setToast(""), 4000)
  }
  const openGame = (game: Game) => {
    setSelected(game)
    go("details")
  }
  const results = initialGames.filter(
    (g) =>
      (sport === "Todos" || g.sport === sport) &&
      (category === "Todas" || g.category === category) &&
      (level === "Todos" || g.level === level) &&
      Number(g.distance.replace(",", ".").split(" ")[0]) <= Number(distance) &&
      (!dateFilter ||
        (dateFilter.endsWith("18")
          ? g.date.includes("18")
          : dateFilter.endsWith("19")
            ? g.date.includes("19")
            : false)) &&
      `${g.name} ${g.city} ${g.place}`
        .toLowerCase()
        .includes(query.toLowerCase()),
  )
  const submitMessage = (e: FormEvent) => {
    e.preventDefault()
    if (!message.trim()) return
    setMessages([...messages, { text: message, mine: true }])
    setMessage("")
  }
  const gameCard = (game: Game) => (
    <article className="game-card" key={game.id}>
      <div className="card-team">
        <Crest team={game.crest} />
        <div>
          <h3>{game.name}</h3>
          <span className="muted">
            <Icon name="pin" size={13} /> {game.city}
          </span>
        </div>
        <span className="distance">{game.distance}</span>
      </div>
      <div className="tags">
        <span className={game.sport === "Futsal" ? "tag purple" : "tag green"}>
          <Icon name="ball" size={13} />
          {game.sport}
        </span>
        <span className="tag">{game.category}</span>
        <span className="tag">{game.level}</span>
      </div>
      <div className="game-meta">
        <span>
          <Icon name="calendar" size={16} />
          {game.date}
        </span>
        <span>
          <Icon name="clock" size={16} />
          {game.time}
        </span>
      </div>
      <div className="game-place">
        <Icon name="pin" size={16} />
        {game.place}
      </div>
      <div className="card-bottom">
        <span>
          <span className="status-dot" />
          Procurando adversário
        </span>
        <button onClick={() => openGame(game)}>
          Ver detalhes <Icon name="arrow" size={16} />
        </button>
      </div>
    </article>
  )
  const sectionTitle = (title: string, subtitle?: string) => (
    <div className="page-heading">
      <div>
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
    </div>
  )
  const upcoming = (
    <div className="panel upcoming">
      <div className="panel-title">
        <h3>Próxima partida</h3>
        <span className="tag green">Confirmada</span>
      </div>
      <div className="versus">
        <div>
          <Crest />
          <strong>{teamName}</strong>
        </div>
        <span>VS</span>
        <div>
          <Crest team="real" />
          <strong>Real Amigos</strong>
        </div>
      </div>
      <div className="match-info">
        <span>
          <Icon name="calendar" size={16} />
          Sábado, 18 de julho
        </span>
        <strong>16:00</strong>
      </div>
      <div className="game-place">
        <Icon name="pin" size={16} />
        Campo do Ibirapuera
      </div>
      <Button
        variant="outline"
        className="full"
        onClick={() => {
          setSelected(initialGames[0])
          go("confirmed")
        }}
      >
        Ver partida <Icon name="arrow" size={16} />
      </Button>
    </div>
  )

  if (page === "loading")
    return (
      <div className="loading-screen" role="status" aria-live="polite">
        <Brand />
        <div className="loading-ball">
          <Icon name="ball" size={42} />
        </div>
        <h2>Preparando o campo…</h2>
        <p>Seu próximo jogo está quase começando.</p>
      </div>
    )

  if (page === "login" || page === "register" || page === "forgot")
    return (
      <div className="auth-page">
        <div className="auth-art">
          <Brand />
          <h1>
            O próximo rival.
            <br />A próxima história.
          </h1>
          <p>O futebol conecta. A gente dá o primeiro passe.</p>
          <div className="field-drawing" />
        </div>
        <div className="auth-content">
          <button className="back-link" onClick={() => go("home")}>
            ← Voltar ao início
          </button>
          <div className="auth-form">
            <div className="eyebrow">BORA PRO JOGO</div>
            <h1>
              {page === "login"
                ? "Seu time em campo."
                : page === "forgot"
                  ? "Recupere seu acesso"
                  : registerStep === 1
                    ? "Vamos começar?"
                    : "Agora, o seu time."}
            </h1>
            <p>
              {page === "login"
                ? "Entre e encontre o próximo adversário."
                : page === "forgot"
                  ? "Informe seu e-mail para receber um link de recuperação."
                  : `Etapa ${registerStep} de 2 · ${
                      registerStep === 1
                        ? "Dados do responsável"
                        : "Perfil do time"
                    }`}
            </p>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                if (page === "forgot") {
                  notify(
                    "Link de recuperação solicitado. Este é um protótipo demonstrativo.",
                  )
                  go("login")
                } else if (page === "register" && registerStep === 1)
                  setRegisterStep(2)
                else {
                  const registered = page === "register"
                  go("loading")
                  window.setTimeout(() => {
                    go("home")
                    notify(
                      registered
                        ? "Perfil criado! Seu time já faz parte do jogo."
                        : "Bem-vindo de volta!",
                    )
                  }, 900)
                }
              }}
            >
              {page === "register" && registerStep === 1 && (
                <>
                  <Field label="Nome do responsável">
                    <input
                      required
                      placeholder="Seu nome"
                      onChange={(e) =>
                        setUserName(e.target.value.split(" ")[0])
                      }
                    />
                  </Field>
                  <Field label="Telefone">
                    <input required type="tel" placeholder="(11) 99999-9999" />
                  </Field>
                </>
              )}
              {(page !== "register" || registerStep === 1) && (
                <Field
                  label={page === "login" ? "Telefone ou e-mail" : "E-mail"}
                >
                  <input
                    required
                    type={page === "login" ? "text" : "email"}
                    placeholder="voce@email.com"
                  />
                </Field>
              )}
              {page !== "forgot" &&
                (page !== "register" || registerStep === 1) && (
                  <Field label="Senha">
                    <input
                      required
                      type="password"
                      minLength={6}
                      placeholder="Pelo menos 6 caracteres"
                    />
                  </Field>
                )}
              {page === "register" && registerStep === 2 && (
                <>
                  <Field label="Nome do time">
                    <input
                      required
                      placeholder="Ex.: União FC"
                      onChange={(e) => setTeamName(e.target.value)}
                    />
                  </Field>
                  <Field label="Escudo do time">
                    <input type="file" accept="image/*" />
                  </Field>
                  <div className="form-grid">
                    <Field label="Modalidade">
                      <select>
                        <option>Futebol</option>
                        <option>Futsal</option>
                      </select>
                    </Field>
                    <Field label="Categoria">
                      <select>
                        {[
                          "Livre",
                          "Sub-15",
                          "Sub-17",
                          "Sub-20",
                          "Veterano",
                        ].map((x) => (
                          <option key={x}>{x}</option>
                        ))}
                      </select>
                    </Field>
                    <Field label="Cidade">
                      <input required placeholder="São Paulo" />
                    </Field>
                    <Field label="Estado">
                      <select>
                        {[
                          "SP",
                          "RJ",
                          "MG",
                          "PR",
                          "RS",
                          "SC",
                          "BA",
                          "PE",
                          "CE",
                          "DF",
                          "GO",
                          "ES",
                          "AC",
                          "AL",
                          "AP",
                          "AM",
                          "MA",
                          "MT",
                          "MS",
                          "PA",
                          "PB",
                          "PI",
                          "RN",
                          "RO",
                          "RR",
                          "SE",
                          "TO",
                        ].map((x) => (
                          <option key={x}>{x}</option>
                        ))}
                      </select>
                    </Field>
                  </div>
                </>
              )}
              {page === "login" && (
                <button
                  type="button"
                  className="text-link forgot"
                  onClick={() => go("forgot")}
                >
                  Esqueci minha senha
                </button>
              )}
              <Button type="submit" className="full">
                {page === "login"
                  ? "Entrar"
                  : page === "forgot"
                    ? "Enviar link"
                    : registerStep === 1
                      ? "Continuar"
                      : "Criar perfil do time"}
                <Icon name="arrow" size={18} />
              </Button>
            </form>
            {page === "login" && (
              <>
                <div className="divider-text">ou continue com</div>
                <Button
                  variant="outline"
                  className="full"
                  onClick={() =>
                    notify(
                      "O login com Google estará disponível na versão conectada.",
                    )
                  }
                >
                  <span className="google">G</span> Entrar com Google
                </Button>
                <p className="auth-switch">
                  Ainda não tem conta?{" "}
                  <button
                    className="text-link"
                    onClick={() => {
                      setRegisterStep(1)
                      go("register")
                    }}
                  >
                    Criar conta
                  </button>
                </p>
              </>
            )}
          </div>
          <span className="auth-footer">
            Joga Contra © 2026 · Feito para quem vive o jogo.
          </span>
        </div>
        {toast && (
          <div className="toast" role="status">
            {toast}
          </div>
        )}
      </div>
    )

  return (
    <div className="app-shell">
      <aside className={`sidebar ${mobileMenu ? "is-open" : ""}`}>
        <Brand />
        <div
          className="sidebar-team"
          onClick={() => go("profile")}
          role="button"
          tabIndex={0}
        >
          <Crest small />
          <div>
            <strong>{teamName}</strong>
            <span>São Paulo, SP</span>
          </div>
          <Icon name="chevron" size={16} />
        </div>
        <span className="nav-caption">SEU JOGO COMEÇA AQUI</span>
        <nav>
          {navItems.map((item) => (
            <button
              key={item.page}
              className={`nav-item ${page === item.page ? "active" : ""}`}
              onClick={() => {
                if (item.page === "create") setEditIndex(null)
                go(item.page)
              }}
            >
              <Icon name={item.icon} />
              <span>{item.label}</span>
              {item.badge && <b>{item.badge}</b>}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="sidebar-promo">
            <Icon name="ball" size={25} />
            <h3>
              Seu próximo rival
              <br />
              está por aqui.
            </h3>
            <p>
              Menos procura.
              <br />
              Mais bola rolando.
            </p>
            <button onClick={() => go("search")}>
              Encontre um jogo <Icon name="arrow" size={16} />
            </button>
            <div className="pitch-lines" />
          </div>
          <button
            className={`nav-item ${page === "profile" ? "active" : ""}`}
            onClick={() => go("profile")}
          >
            <Icon name="user" />
            Perfil do time
          </button>
          <div className="sidebar-user">
            <div className="avatar">JS</div>
            <div>
              <strong>{userName} Silva</strong>
              <span>Responsável pelo time</span>
            </div>
            <button aria-label="Sair" onClick={() => go("login")}>
              <Icon name="logout" size={18} />
            </button>
          </div>
        </div>
      </aside>
      <div className="main-shell">
        <header className="topbar">
          <div className="breadcrumb">
            <button
              className="mobile-menu"
              aria-label="Abrir menu"
              onClick={() => setMobileMenu(!mobileMenu)}
            >
              <Icon name="menu" />
            </button>
            <span>Joga Contra</span>
            <Icon name="chevron" size={13} />
            <strong>{titles[page]}</strong>
          </div>
          <div className="topbar-actions">
            <button
              className="location-button"
              onClick={() => {
                go("search")
                setFilters(true)
              }}
            >
              <Icon name="pin" size={17} />
              <span>São Paulo, SP</span>
              <span className="down-chevron">⌄</span>
            </button>
            <div className="topbar-separator" />
            <button
              className="notification-button"
              aria-label="Notificações"
              onClick={() => go("notifications")}
            >
              <Icon name="bell" />
              <i />
            </button>
            <button
              className="avatar"
              aria-label="Meu perfil"
              onClick={() => go("profile")}
            >
              JS
            </button>
          </div>
        </header>
        <main>
          {page === "home" && (
            <>
              <div className="welcome-row">
                <div>
                  <div className="eyebrow">
                    A SEMANA FICA MELHOR COM FUTEBOL
                  </div>
                  <h1>
                    Fala, {userName}. Bora pro jogo?{" "}
                    <span className="greeting-ball">
                      <Icon name="ball" size={29} />
                    </span>
                  </h1>
                  <p>
                    Seu próximo adversário está mais perto do que você imagina.
                  </p>
                </div>
                <div className="today">
                  <Icon name="calendar" size={16} />
                  Quinta-feira, 16 de julho
                </div>
              </div>
              <section className="hero">
                <div className="hero-copy">
                  <div className="hero-eyebrow">
                    <span />O FUTEBOL NÃO PODE PARAR
                  </div>
                  <h2>
                    Seu time tá pronto.
                    <br />
                    Só falta o <em>rival.</em>
                  </h2>
                  <p>
                    Encontre times da sua região e transforme
                    <br className="desktop-break" /> a vontade de jogar em
                    partida marcada.
                  </p>
                  <div className="hero-actions">
                    <Button onClick={() => go("search")}>
                      <Icon name="search" size={19} />
                      Encontrar adversário
                      <Icon name="arrow" size={18} />
                    </Button>
                    <Button
                      variant="hero"
                      onClick={() => {
                        setEditIndex(null)
                        go("create")
                      }}
                    >
                      <Icon name="plus" size={18} />
                      Anunciar jogo
                    </Button>
                  </div>
                  <div className="hero-social">
                    <div className="avatar-stack">
                      <span>RM</span>
                      <span>VL</span>
                      <span>AC</span>
                    </div>
                    <span>
                      <strong>+1.200 times</strong> já estão em campo
                    </span>
                  </div>
                </div>
                <div className="hero-image" />
                <div className="hero-photo-tag">
                  <span className="live-dot" />O próximo jogo começa aqui.
                </div>
              </section>
              <div className="dashboard-grid">
                <section className="available-section">
                  <div className="section-heading">
                    <div>
                      <h2>Um rival à altura. Perto de você.</h2>
                      <p>Times com a mesma vontade de entrar em campo.</p>
                    </div>
                    <button className="text-link" onClick={() => go("search")}>
                      Ver todos
                      <Icon name="arrow" size={16} />
                    </button>
                  </div>
                  <div className="filter-row">
                    <div className="sport-tabs">
                      {["Todos", "Futebol", "Futsal"].map((s) => (
                        <button
                          className={sport === s ? "selected" : ""}
                          onClick={() => setSport(s)}
                          key={s}
                        >
                          {s !== "Todos" && <Icon name="ball" size={15} />}
                          {s}
                        </button>
                      ))}
                    </div>
                    <button
                      className="filter-button"
                      onClick={() => {
                        go("search")
                        setFilters(true)
                      }}
                    >
                      <Icon name="filter" size={16} />
                      Filtros
                    </button>
                  </div>
                  <div className="games-grid">{results.map(gameCard)}</div>
                  <div className="local-note">
                    <Icon name="pin" size={16} />
                    Mostrando jogos em um raio de 25 km de São Paulo
                  </div>
                </section>
                <aside className="right-column">
                  {upcoming}
                  <div className="panel team-summary">
                    <div className="panel-title">
                      <h3>Seu time, em campo</h3>
                      <Icon name="shield" size={19} />
                    </div>
                    <div className="team-summary-header">
                      <Crest />
                      <div>
                        <h3>{teamName}</h3>
                        <span>Futebol · Categoria livre</span>
                        <div className="rating">
                          <Icon name="star" size={13} />
                          4,9 <span>· 12 avaliações</span>
                        </div>
                      </div>
                    </div>
                    <div className="team-stats">
                      <div>
                        <strong>18</strong>
                        <span>Jogos realizados</span>
                      </div>
                      <div>
                        <strong>
                          98<span>%</span>
                        </strong>
                        <span>Comprometimento</span>
                      </div>
                    </div>
                    <button className="text-link" onClick={() => go("profile")}>
                      Ver perfil do time
                      <Icon name="arrow" size={16} />
                    </button>
                  </div>
                  <div className="tip-card">
                    <div className="tip-icon">
                      <Icon name="trophy" size={22} />
                    </div>
                    <div>
                      <strong>Rivalidade só dentro de campo.</strong>
                      <p>Respeito e compromisso fazem parte de um bom jogo.</p>
                    </div>
                  </div>
                </aside>
              </div>
              <footer className="page-footer">
                <span>Futebol de verdade. Conexões de verdade.</span>
                <span>Joga Contra © 2026</span>
              </footer>
            </>
          )}
          {page === "search" && (
            <>
              {sectionTitle(
                "Encontre seu próximo adversário",
                "Um bom jogo começa com um bom encontro.",
              )}
              <div className="search-toolbar">
                <div className="search-input">
                  <Icon name="search" />
                  <input
                    placeholder="Busque um time, cidade ou região"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                  />
                </div>
                <Button variant="outline" onClick={() => go("map")}>
                  <Icon name="map" size={18} />
                  Ver no mapa
                </Button>
              </div>
              <div className="filter-row">
                <div className="sport-tabs">
                  {["Todos", "Futebol", "Futsal"].map((s) => (
                    <button
                      className={sport === s ? "selected" : ""}
                      key={s}
                      onClick={() => setSport(s)}
                    >
                      {s}
                    </button>
                  ))}
                </div>
                <Button variant="outline" onClick={() => setFilters(!filters)}>
                  <Icon name="filter" size={18} />
                  Filtros
                </Button>
              </div>
              {filters && (
                <form
                  className="panel filters-panel"
                  onSubmit={(e) => {
                    e.preventDefault()
                    setFilters(false)
                    notify("Filtros aplicados")
                  }}
                >
                  <div className="form-grid">
                    <Field label="Data disponível">
                      <input
                        type="date"
                        aria-label="Qualquer data"
                        value={dateFilter}
                        onChange={(e) => setDateFilter(e.target.value)}
                      />
                    </Field>
                    <Field label="Cidade ou região">
                      <input
                        placeholder="São Paulo"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                      />
                    </Field>
                    <Field label="Raio de distância">
                      <select
                        value={distance}
                        onChange={(e) => setDistance(e.target.value)}
                      >
                        {["5", "10", "25", "50", "100"].map((d) => (
                          <option key={d} value={d}>
                            {d} km
                          </option>
                        ))}
                      </select>
                    </Field>
                    <Field label="Categoria">
                      <select
                        value={category}
                        onChange={(e) => setCategory(e.target.value)}
                      >
                        {[
                          "Todas",
                          "Livre",
                          "Sub-15",
                          "Sub-17",
                          "Sub-20",
                          "Veterano",
                        ].map((s) => (
                          <option key={s}>{s}</option>
                        ))}
                      </select>
                    </Field>
                    <Field label="Nível do time">
                      <select
                        value={level}
                        onChange={(e) => setLevel(e.target.value)}
                      >
                        {[
                          "Todos",
                          "Recreativo",
                          "Intermediário",
                          "Avançado",
                        ].map((s) => (
                          <option key={s}>{s}</option>
                        ))}
                      </select>
                    </Field>
                  </div>
                  <div className="form-actions">
                    <Button
                      variant="outline"
                      onClick={() => {
                        setCategory("Todas")
                        setLevel("Todos")
                        setDistance("25")
                        setDateFilter("")
                        setQuery("")
                        setSport("Todos")
                      }}
                    >
                      Limpar filtros
                    </Button>
                    <Button type="submit">Aplicar filtros</Button>
                  </div>
                </form>
              )}
              <p className="results-count">
                {results.length} jogos disponíveis{" "}
                {dateFilter ? "" : "· Qualquer data"}
              </p>
              <div className="games-grid search-grid">
                {results.map(gameCard)}
              </div>
              {!results.length && (
                <Empty
                  icon="search"
                  title="Nenhum rival por aqui. Ainda."
                  text="Amplie a distância ou tente outros filtros para encontrar seu próximo jogo."
                  action={
                    <Button
                      onClick={() => {
                        setQuery("")
                        setSport("Todos")
                        setCategory("Todas")
                        setLevel("Todos")
                        setDateFilter("")
                        setDistance("25")
                      }}
                    >
                      Limpar filtros
                    </Button>
                  }
                />
              )}
            </>
          )}
          {page === "details" && (
            <>
              <button className="back-link" onClick={() => go("search")}>
                ← Voltar aos jogos
              </button>
              {sectionTitle(
                "Tem jogo esperando pelo seu time.",
                "Confira os detalhes e dê o primeiro passe.",
              )}
              <div className="detail-layout">
                <div className="panel detail-panel">
                  <div className="detail-team">
                    <Crest team={selected.crest} />
                    <div>
                      <span className="tag green">Procurando adversário</span>
                      <h2>{selected.name}</h2>
                      <span className="muted">
                        <Icon name="pin" size={16} />
                        {selected.city} · {selected.distance} de você
                      </span>
                    </div>
                  </div>
                  <div className="tags">
                    <span className="tag green">{selected.sport}</span>
                    <span className="tag">{selected.category}</span>
                    <span className="tag">{selected.level}</span>
                  </div>
                  <div className="detail-data">
                    {[
                      ["calendar", "Data", `${selected.date} de 2026`],
                      ["clock", "Horário", selected.time],
                      ["pin", "Local", selected.place],
                      ["home", "Mando de campo", selected.home],
                      [
                        "user",
                        "Jogadores",
                        selected.sport === "Futsal"
                          ? "5 por equipe"
                          : "11 por equipe",
                      ],
                      ["ball", "Aluguel do espaço", "R$ 120 por time"],
                    ].map(([icon, label, value]) => (
                      <div key={label}>
                        <Icon name={icon as IconName} />
                        <span>
                          <small>{label}</small>
                          <strong>{value}</strong>
                        </span>
                      </div>
                    ))}
                  </div>
                  <h3>Sobre o jogo</h3>
                  <p className="body-text">
                    Estamos procurando um time parceiro para um amistoso! A
                    ideia é jogar uma boa partida, com respeito e muita bola no
                    pé. O espaço já está reservado. Podemos dividir a taxa do
                    campo. Bora jogar?
                  </p>
                  <div className="detail-callout">
                    <Icon name="shield" />
                    Compromisso e respeito dentro e fora de campo.
                  </div>
                  <Button className="full" onClick={() => setModal("interest")}>
                    <Icon name="ball" size={18} />
                    Tenho interesse
                  </Button>
                </div>
                <div className="panel opponent-profile">
                  <Crest team={selected.crest} />
                  <h2>{selected.name}</h2>
                  <p>{selected.city}</p>
                  <div className="rating">
                    <Icon name="star" />
                    4,9 <span>· 12 avaliações</span>
                  </div>
                  <div className="team-stats">
                    <div>
                      <strong>24</strong>
                      <span>Jogos realizados</span>
                    </div>
                    <div>
                      <strong>2010</strong>
                      <span>Fundação</span>
                    </div>
                  </div>
                  <h3>Um time de amigos, um só futebol.</h3>
                  <p className="body-text">
                    A gente joga pela resenha, pela amizade e por aquele gol no
                    último minuto. Categoria {selected.category.toLowerCase()},
                    nível {selected.level.toLowerCase()}.
                  </p>
                  <span className="tag green">
                    <Icon name="check" size={14} />
                    Time verificado
                  </span>
                </div>
              </div>
            </>
          )}
          {page === "create" && (
            <>
              {sectionTitle(
                editIndex !== null
                  ? "Edite seu anúncio"
                  : "O seu time procura um rival?",
                "Publique um jogo em poucos passos. Deixe o resto com a gente.",
              )}
              <form
                className="panel create-form"
                onSubmit={(e) => {
                  e.preventDefault()
                  const data = new FormData(e.currentTarget)
                  const title = `${teamName} · ${data.get("sport")} · ${data.get("date")}`
                  if (editIndex !== null)
                    setAds(
                      ads.map((a, i) =>
                        i === editIndex ? { ...a, title } : a,
                      ),
                    )
                  else setAds([...ads, { title, status: "Ativo" }])
                  setModal("published")
                }}
              >
                <div className="form-section-title">
                  <span>01</span>
                  <div>
                    <h3>Como vai ser o jogo?</h3>
                    <p>Conte um pouco sobre a sua equipe.</p>
                  </div>
                </div>
                <div className="form-grid">
                  <Field label="Modalidade">
                    <select name="sport">
                      <option>Futebol</option>
                      <option>Futsal</option>
                    </select>
                  </Field>
                  <Field label="Categoria">
                    <select>
                      {["Livre", "Sub-15", "Sub-17", "Sub-20", "Veterano"].map(
                        (s) => (
                          <option key={s}>{s}</option>
                        ),
                      )}
                    </select>
                  </Field>
                  <Field label="Nível do time">
                    <select>
                      <option>Intermediário</option>
                      <option>Recreativo</option>
                      <option>Avançado</option>
                    </select>
                  </Field>
                  <Field label="Quantidade de jogadores">
                    <input
                      required
                      type="number"
                      min="5"
                      max="30"
                      defaultValue="11"
                    />
                  </Field>
                </div>
                <div className="form-section-title">
                  <span>02</span>
                  <div>
                    <h3>Quando e onde?</h3>
                    <p>O primeiro passo para uma partida marcada.</p>
                  </div>
                </div>
                <div className="form-grid">
                  <Field label="Data">
                    <input required name="date" type="date" min="2026-07-16" />
                  </Field>
                  <Field label="Horário">
                    <input required type="time" defaultValue="16:00" />
                  </Field>
                  <Field label="Cidade">
                    <input required defaultValue="São Paulo" />
                  </Field>
                  <Field label="Bairro / região">
                    <input required placeholder="Ex.: Vila Mariana" />
                  </Field>
                  <Field label="Local da partida">
                    <input required placeholder="Nome do campo ou quadra" />
                  </Field>
                  <Field label="Mando de campo">
                    <select>
                      <option>Jogo em casa</option>
                      <option>Jogo fora</option>
                      <option>Indiferente</option>
                    </select>
                  </Field>
                  <Field label="Taxa de aluguel por time (R$)">
                    <input type="number" min="0" placeholder="0,00" />
                  </Field>
                </div>
                <Field label="Observações">
                  <textarea
                    rows={4}
                    placeholder="Que tal contar mais sobre o jogo? Regras, estrutura e o que o adversário precisa saber."
                  />
                </Field>
                <div className="form-actions">
                  <span className="muted">
                    <Icon name="shield" size={16} />
                    Um bom jogo começa com compromisso.
                  </span>
                  <Button type="submit">
                    <Icon name="plus" size={18} />
                    {editIndex !== null
                      ? "Salvar alterações"
                      : "Publicar anúncio"}
                  </Button>
                </div>
              </form>
            </>
          )}
          {page === "conversations" && (
            <>
              {sectionTitle(
                "A conversa que vira jogo.",
                "Combine os detalhes com os responsáveis de cada time.",
              )}
              <div className="panel conversation-list">
                {[initialGames[0], initialGames[1]].map((g, i) => (
                  <button
                    key={g.id}
                    onClick={() => {
                      setSelected(g)
                      go("chat")
                    }}
                  >
                    <Crest team={g.crest} />
                    <div>
                      <h3>{g.name}</h3>
                      <p>
                        {i === 0
                          ? "Vocês conseguem jogar sábado às 16h?"
                          : "Olá! Nossa quadra está disponível domingo."}
                      </p>
                      <span className="tag green">Negociando partida</span>
                    </div>
                    <div className="conversation-time">
                      <span>{i === 0 ? "14:32" : "Ontem"}</span>
                      <b>{i === 0 ? "2" : "1"}</b>
                    </div>
                  </button>
                ))}
              </div>
            </>
          )}
          {page === "chat" && (
            <>
              <button className="back-link" onClick={() => go("conversations")}>
                ← Todas as conversas
              </button>
              <div className="chat-layout">
                <div className="panel chat-panel">
                  <div className="chat-header">
                    <Crest small team={selected.crest} />
                    <div>
                      <h3>{selected.name}</h3>
                      <span>
                        <i className="status-dot" />
                        Carlos · Responsável pelo time
                      </span>
                    </div>
                    <Icon name="shield" />
                  </div>
                  <div className="chat-messages">
                    <div className="chat-date">Hoje</div>
                    <div className="chat-system">
                      {teamName} demonstrou interesse no jogo de {selected.name}
                      .
                    </div>
                    {messages.map((m, i) => (
                      <div
                        key={i}
                        className={`message ${m.mine ? "mine" : ""}`}
                      >
                        <p>{m.text}</p>
                        <small>
                          14:{30 + i}{" "}
                          {m.mine && <Icon name="check" size={12} />}
                        </small>
                      </div>
                    ))}
                  </div>
                  <form className="chat-input" onSubmit={submitMessage}>
                    <label className="icon-button" aria-label="Enviar imagem">
                      <Icon name="image" />
                      <input
                        type="file"
                        accept="image/*"
                        hidden
                        onChange={(e) => {
                          if (e.target.files?.[0])
                            setMessages([
                              ...messages,
                              {
                                text: `Imagem compartilhada: ${e.target.files[0].name}`,
                                mine: true,
                              },
                            ])
                        }}
                      />
                    </label>
                    <button
                      type="button"
                      className="icon-button"
                      aria-label="Compartilhar localização"
                      onClick={() =>
                        setMessages([
                          ...messages,
                          {
                            text: `Localização: ${selected.place}, São Paulo · https://maps.google.com/?q=${encodeURIComponent(selected.place + " São Paulo")}`,
                            mine: true,
                          },
                        ])
                      }
                    >
                      <Icon name="pin" />
                    </button>
                    <input
                      placeholder="Escreva sua mensagem…"
                      value={message}
                      onChange={(e) => setMessage(e.target.value)}
                    />
                    <button
                      className="send-button"
                      aria-label="Enviar mensagem"
                    >
                      <Icon name="send" size={19} />
                    </button>
                  </form>
                </div>
                <div className="panel chat-match">
                  <span className="tag green">
                    {confirmed ? "Confirmada" : "Em negociação"}
                  </span>
                  <h3>Quase tudo pronto!</h3>
                  <div className="versus">
                    <div>
                      <Crest />
                      <strong>{teamName}</strong>
                    </div>
                    <span>VS</span>
                    <div>
                      <Crest team={selected.crest} />
                      <strong>{selected.name}</strong>
                    </div>
                  </div>
                  <p>
                    <Icon name="calendar" size={18} />
                    {selected.date} · {selected.time}
                  </p>
                  <p>
                    <Icon name="pin" size={18} />
                    {selected.place}
                  </p>
                  <Button
                    className="full"
                    onClick={() =>
                      confirmed ? go("confirmed") : setModal("confirm")
                    }
                  >
                    {confirmed ? "Ver partida" : "Confirmar partida"}
                    <Icon name="check" size={18} />
                  </Button>
                  <small>
                    Confirme quando todos os detalhes estiverem combinados.
                  </small>
                </div>
              </div>
            </>
          )}
          {page === "confirmed" && (
            <>
              <div className="confirmed-heading">
                <div className="success-icon">
                  <Icon name="check" size={32} />
                </div>
                <div className="eyebrow">AGORA É SÓ ENTRAR EM CAMPO</div>
                <h1>Partida confirmada!</h1>
                <p>Chame a equipe. Seu próximo jogo já tem dia e hora.</p>
              </div>
              <div className="panel confirmed-card">
                <span className="tag green">Amistoso · {selected.sport}</span>
                <div className="versus big">
                  <div>
                    <Crest />
                    <strong>{teamName}</strong>
                    <span>São Paulo, SP</span>
                  </div>
                  <span>VS</span>
                  <div>
                    <Crest team={selected.crest} />
                    <strong>{selected.name}</strong>
                    <span>{selected.city}</span>
                  </div>
                </div>
                <div className="confirmation-info">
                  <div>
                    <Icon name="calendar" />
                    <span>
                      Data<strong>{selected.date} de 2026</strong>
                    </span>
                  </div>
                  <div>
                    <Icon name="clock" />
                    <span>
                      Horário<strong>{selected.time}</strong>
                    </span>
                  </div>
                  <div>
                    <Icon name="pin" />
                    <span>
                      Local<strong>{selected.place}</strong>
                      <small>
                        Av. República do Líbano, 1111 · São Paulo, SP
                      </small>
                    </span>
                  </div>
                </div>
                <div className="form-actions">
                  <Button
                    variant="outline"
                    onClick={() =>
                      window.open(
                        `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(selected.place + " São Paulo")}`,
                        "_blank",
                        "noopener,noreferrer",
                      )
                    }
                  >
                    <Icon name="pin" size={18} />
                    Abrir localização
                  </Button>
                  <Button onClick={() => go("chat")}>
                    <Icon name="chat" size={18} />
                    Conversar
                  </Button>
                </div>
                <button
                  className="danger-link"
                  onClick={() => setModal("cancel")}
                >
                  Cancelar partida
                </button>
              </div>
            </>
          )}
          {page === "games" && (
            <>
              {sectionTitle(
                "Toda partida tem uma história.",
                "Acompanhe seus jogos, da primeira conversa ao apito final.",
              )}
              <div className="sport-tabs games-tabs">
                {[
                  "Todos",
                  "Aguardando",
                  "Negociando",
                  "Confirmado",
                  "Realizado",
                  "Cancelado",
                ].map((s) => (
                  <button
                    key={s}
                    className={gameTab === s ? "selected" : ""}
                    onClick={() => setGameTab(s)}
                  >
                    {s}
                  </button>
                ))}
              </div>
              <div className="games-list">
                {["Aguardando", "Negociando", "Confirmado", "Realizado"]
                  .filter((s) => gameTab === "Todos" || gameTab === s)
                  .map((status, i) => (
                    <div className="panel game-list-item" key={status}>
                      <div className="game-list-teams">
                        <Crest small />
                        <strong>{teamName}</strong>
                        <span>vs</span>
                        <Crest small team={initialGames[i].crest} />
                        <strong>
                          {status === "Aguardando"
                            ? "Adversário a definir"
                            : initialGames[i].name}
                        </strong>
                      </div>
                      <div className="game-list-date">
                        <Icon name="calendar" size={16} />
                        {initialGames[i].date} · {initialGames[i].time}
                      </div>
                      <span
                        className={`tag ${
                          status === "Confirmado"
                            ? "green"
                            : status === "Negociando"
                              ? "orange"
                              : ""
                        }`}
                      >
                        {status}
                      </span>
                      <Button
                        variant="outline"
                        onClick={() => {
                          setSelected(initialGames[i])
                          go(
                            status === "Realizado"
                              ? "review"
                              : status === "Confirmado"
                                ? "confirmed"
                                : status === "Negociando"
                                  ? "chat"
                                  : "ads",
                          )
                        }}
                      >
                        {status === "Realizado" ? "Avaliar" : "Ver detalhes"}
                        <Icon name="arrow" size={16} />
                      </Button>
                    </div>
                  ))}
              </div>
              {gameTab === "Cancelado" && (
                <Empty
                  icon="calendar"
                  title="Nenhuma partida cancelada"
                  text="Bom sinal! Compromisso também faz parte do jogo."
                />
              )}
            </>
          )}
          {page === "ads" && (
            <>
              {sectionTitle(
                "Seus anúncios, suas próximas partidas.",
                "Gerencie seus jogos e encontre quem está pronto para jogar.",
              )}
              <Button
                onClick={() => {
                  setEditIndex(null)
                  go("create")
                }}
              >
                <Icon name="plus" size={18} />
                Novo anúncio
              </Button>
              <div className="ads-list">
                {ads.map((a, i) => (
                  <div className="panel ad-item" key={i}>
                    <div className="ad-header">
                      <Crest small />
                      <div>
                        <h3>{a.title}</h3>
                        <p>Futebol · Livre · São Paulo, SP</p>
                      </div>
                      <span
                        className={`tag ${a.status === "Ativo" ? "green" : ""}`}
                      >
                        {a.status}
                      </span>
                    </div>
                    <div className="ad-actions">
                      <button
                        onClick={() => {
                          setEditIndex(i)
                          go("create")
                        }}
                      >
                        <Icon name="edit" size={16} />
                        Editar
                      </button>
                      <button
                        onClick={() =>
                          setAds(
                            ads.map((x, index) =>
                              index === i
                                ? {
                                    ...x,
                                    status:
                                      x.status === "Ativo"
                                        ? "Pausado"
                                        : "Ativo",
                                  }
                                : x,
                            ),
                          )
                        }
                      >
                        {a.status === "Ativo"
                          ? "Pausar anúncio"
                          : "Reativar anúncio"}
                      </button>
                      <button onClick={() => go("conversations")}>
                        <Icon name="user" size={16} />
                        Ver interessados <b>2</b>
                      </button>
                      <button
                        className="danger-link"
                        onClick={() => setModal(`delete-${i}`)}
                      >
                        <Icon name="trash" size={16} />
                        Excluir
                      </button>
                    </div>
                  </div>
                ))}
              </div>
              {!ads.length && (
                <Empty
                  icon="flag"
                  title="Seu próximo jogo começa aqui."
                  text="Você ainda não publicou um anúncio. Conte quando seu time está disponível!"
                  action={
                    <Button onClick={() => go("create")}>Anunciar jogo</Button>
                  }
                />
              )}
            </>
          )}
          {page === "profile" && (
            <>
              {sectionTitle(
                "Seu time. Sua identidade.",
                "Dentro e fora de campo, esse é o seu cartão de visita.",
              )}
              <div className="profile-cover">
                <div className="pitch-lines" />
              </div>
              <div className="panel profile-panel">
                <div className="profile-main">
                  <Crest />
                  <div>
                    <h1>{teamName}</h1>
                    <p>
                      <Icon name="pin" size={16} />
                      São Paulo, SP <span>· Desde 2015</span>
                    </p>
                    <div className="tags">
                      <span className="tag green">Futebol</span>
                      <span className="tag">Livre</span>
                      <span className="tag">Intermediário</span>
                    </div>
                  </div>
                  <Button
                    variant="outline"
                    onClick={() => setModal("edit-profile")}
                  >
                    <Icon name="edit" size={16} />
                    Editar perfil
                  </Button>
                </div>
                <div className="profile-body">
                  <section>
                    <h2>Mais que um time, uma família.</h2>
                    <p className="body-text">
                      Desde 2015, reunimos amigos que compartilham a paixão pelo
                      futebol. Jogamos com raça, respeito e aquela resenha que
                      não pode faltar. Estamos sempre prontos para um bom
                      amistoso!
                    </p>
                    <div className="detail-data">
                      <div>
                        <Icon name="user" />
                        <span>
                          <small>Responsável</small>
                          <strong>{userName} Silva</strong>
                        </span>
                      </div>
                      <div>
                        <Icon name="chat" />
                        <span>
                          <small>Contato</small>
                          <strong>(11) 99999-1234</strong>
                        </span>
                      </div>
                    </div>
                    <h3>Histórico de jogos</h3>
                    <div className="history-row">
                      <Crest small team="real" />
                      <span>
                        {teamName} <b>2 × 1</b> Real Amigos FC
                      </span>
                      <small>11 jul 2026</small>
                    </div>
                    <div className="history-row">
                      <Crest small team="atletico" />
                      <span>
                        {teamName} <b>1 × 1</b> Atlético da Zona Sul
                      </span>
                      <small>4 jul 2026</small>
                    </div>
                  </section>
                  <section>
                    <div className="team-stats">
                      <div>
                        <strong>18</strong>
                        <span>Jogos realizados</span>
                      </div>
                      <div>
                        <strong>
                          4,9 <Icon name="star" size={18} />
                        </strong>
                        <span>Avaliação geral</span>
                      </div>
                    </div>
                    <h3>Quem já jogou com a gente</h3>
                    <div className="review-quote">
                      <div className="rating">★★★★★</div>
                      <p>
                        “Time pontual, organizado e com muito respeito em campo.
                        Bora marcar a próxima!”
                      </p>
                      <span>Real Amigos FC · Julho de 2026</span>
                    </div>
                    <Button
                      variant="outline"
                      className="full"
                      onClick={() => go("games")}
                    >
                      Ver todos os jogos
                      <Icon name="arrow" size={16} />
                    </Button>
                  </section>
                </div>
              </div>
            </>
          )}
          {page === "notifications" && (
            <>
              {sectionTitle(
                "O jogo não para.",
                "Fique por dentro de tudo que acontece com o seu time.",
              )}
              <div className="panel notifications-list">
                {[
                  {
                    icon: "ball",
                    title: "Tem rival querendo jogo!",
                    text: "O time Real Amigos demonstrou interesse no seu anúncio.",
                    time: "Há 5 minutos",
                    next: "chat",
                  },
                  {
                    icon: "check",
                    title: "Pode chamar a equipe.",
                    text: "Sua partida contra o Real Amigos FC foi confirmada.",
                    time: "Há 30 minutos",
                    next: "confirmed",
                  },
                  {
                    icon: "chat",
                    title: "A conversa tá rolando.",
                    text: "Você recebeu uma nova mensagem de Vila Nova Futsal.",
                    time: "Há 1 hora",
                    next: "conversations",
                  },
                  {
                    icon: "clock",
                    title: "Seu anúncio está próximo de expirar.",
                    text: "Atualize a disponibilidade para continuar encontrando adversários.",
                    time: "Ontem",
                    next: "ads",
                  },
                ].map((n) => (
                  <button key={n.title} onClick={() => go(n.next)}>
                    <div className="notification-icon">
                      <Icon name={n.icon as IconName} />
                    </div>
                    <div>
                      <h3>{n.title}</h3>
                      <p>{n.text}</p>
                      <small>{n.time}</small>
                    </div>
                    <Icon name="chevron" size={18} />
                  </button>
                ))}
              </div>
            </>
          )}
          {page === "review" && (
            <>
              {sectionTitle(
                "Como foi o jogo?",
                "Sua avaliação ajuda a construir uma comunidade que joga junto.",
              )}
              <form
                className="panel review-form"
                onSubmit={(e) => {
                  e.preventDefault()
                  if (Object.keys(rating).length < 4) {
                    notify("Avalie todos os critérios antes de enviar.")
                    return
                  }
                  setModal("reviewed")
                }}
              >
                <div className="detail-team">
                  <Crest team={selected.crest} />
                  <div>
                    <h2>{selected.name}</h2>
                    <p>
                      {selected.date} · {selected.place}
                    </p>
                  </div>
                </div>
                {[
                  "Pontualidade",
                  "Organização",
                  "Respeito",
                  "Estrutura do local",
                ].map((label) => (
                  <div className="rating-row" key={label}>
                    <strong>{label}</strong>
                    <div>
                      {[1, 2, 3, 4, 5].map((v) => (
                        <button
                          type="button"
                          key={v}
                          aria-label={`${v} estrelas para ${label}`}
                          className={(rating[label] || 0) >= v ? "rated" : ""}
                          onClick={() => setRating({ ...rating, [label]: v })}
                        >
                          <Icon name="star" size={27} />
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
                <Field label="Deixe um comentário">
                  <textarea
                    rows={4}
                    placeholder="Conte como foi a experiência de jogar com esse time."
                  />
                </Field>
                <Button type="submit" className="full">
                  Enviar avaliação
                  <Icon name="star" size={18} />
                </Button>
              </form>
            </>
          )}
          {page === "map" && (
            <>
              {sectionTitle(
                "O futebol acontece perto de você.",
                "Explore os campos, quadras e times da sua região.",
              )}
              <div className="map-layout">
                <div className="map-surface">
                  <div className="map-park park-one" />
                  <div className="map-park park-two" />
                  <div className="map-road road-one" />
                  <div className="map-road road-two" />
                  <div className="map-road road-three" />
                  <span className="map-label label-one">VILA MARIANA</span>
                  <span className="map-label label-two">IBIRAPUERA</span>
                  <span className="map-label label-three">SAÚDE</span>
                  <span className="map-label label-four">MOEMA</span>
                  <div className="map-you">
                    <span />
                    Você está aqui
                  </div>
                  {initialGames.map((g, i) => (
                    <button
                      className={`map-marker marker-${i}`}
                      key={g.id}
                      aria-label={`Ver jogo: ${g.name}`}
                      onClick={() => setSelected(g)}
                    >
                      <Icon name="ball" size={22} />
                      <span>{g.name}</span>
                    </button>
                  ))}
                  <div className="map-caption">
                    <Icon name="map" size={16} />
                    Mapa ilustrativo · São Paulo, SP
                  </div>
                </div>
                <aside className="map-results">
                  <h3>Perto de você</h3>
                  {gameCard(selected)}
                  {initialGames
                    .filter((g) => g.id !== selected.id)
                    .slice(0, 2)
                    .map((g) => (
                      <button
                        className="map-list-item"
                        key={g.id}
                        onClick={() => setSelected(g)}
                      >
                        <Crest small team={g.crest} />
                        <div>
                          <strong>{g.name}</strong>
                          <span>
                            {g.distance} · {g.sport}
                          </span>
                        </div>
                        <Icon name="chevron" size={16} />
                      </button>
                    ))}
                </aside>
              </div>
            </>
          )}
        </main>
      </div>
      <nav className="bottom-nav">
        {[
          { page: "home", label: "Início", icon: "home" },
          { page: "search", label: "Buscar", icon: "search" },
          { page: "create", label: "Anunciar", icon: "plus" },
          { page: "conversations", label: "Conversas", icon: "chat" },
          { page: "profile", label: "Perfil", icon: "user" },
        ].map((n) => (
          <button
            className={`${page === n.page ? "active" : ""} ${
              n.page === "create" ? "nav-create" : ""
            }`}
            onClick={() => go(n.page)}
            key={n.page}
          >
            <Icon name={n.icon as IconName} />
            <span>{n.label}</span>
          </button>
        ))}
      </nav>
      {toast && (
        <div className="toast" role="status">
          <Icon name="check" size={18} />
          {toast}
          <button aria-label="Fechar mensagem" onClick={() => setToast("")}>
            <Icon name="close" size={16} />
          </button>
        </div>
      )}
      {modal && (
        <div className="modal-overlay" onClick={() => setModal("")}>
          <section
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="modal-title"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              className="modal-close"
              aria-label="Fechar"
              onClick={() => setModal("")}
            >
              <Icon name="close" />
            </button>
            <div
              className={`success-icon ${
                modal.includes("delete") || modal === "cancel" ? "warning" : ""
              }`}
            >
              <Icon
                name={
                  modal.includes("delete")
                    ? "trash"
                    : modal === "cancel"
                      ? "close"
                      : modal === "interest"
                        ? "ball"
                        : modal === "edit-profile"
                          ? "edit"
                          : "check"
                }
                size={30}
              />
            </div>
            <h2 id="modal-title">
              {modal === "interest"
                ? "Bora marcar esse jogo?"
                : modal === "confirm"
                  ? "Tudo combinado?"
                  : modal === "published"
                    ? "Seu anúncio está no jogo!"
                    : modal === "reviewed"
                      ? "Valeu pelo feedback!"
                      : modal === "cancel"
                        ? "Cancelar a partida?"
                        : modal === "edit-profile"
                          ? "Seu time, do seu jeito."
                          : "Excluir este anúncio?"}
            </h2>
            <p>
              {modal === "interest"
                ? "Você quer demonstrar interesse neste jogo? Vamos abrir uma conversa com o responsável pelo time."
                : modal === "confirm"
                  ? `Confirme a partida de ${teamName} contra ${selected.name}, ${selected.date} às ${selected.time}.`
                  : modal === "published"
                    ? "Agora os times da sua região podem encontrar seu anúncio e demonstrar interesse."
                    : modal === "reviewed"
                      ? "Sua avaliação ajuda todo mundo a encontrar bons adversários."
                      : modal === "cancel"
                        ? "O outro time será avisado. Tenha certeza antes de cancelar."
                        : modal === "edit-profile"
                          ? "Atualize a identidade do seu time."
                          : "Esta ação não pode ser desfeita. Os interessados não poderão mais encontrar este jogo."}
            </p>
            {modal === "edit-profile" ? (
              <form
                onSubmit={(e) => {
                  e.preventDefault()
                  const data = new FormData(e.currentTarget)
                  setTeamName(String(data.get("name")))
                  setModal("")
                  notify("Perfil atualizado com sucesso!")
                }}
              >
                <Field label="Nome do time">
                  <input name="name" required defaultValue={teamName} />
                </Field>
                <Button type="submit" className="full">
                  Salvar perfil
                </Button>
              </form>
            ) : (
              <div className="modal-actions">
                <Button variant="outline" onClick={() => setModal("")}>
                  {modal === "published" || modal === "reviewed"
                    ? "Fechar"
                    : "Agora não"}
                </Button>
                <Button
                  variant={
                    modal.includes("delete") || modal === "cancel"
                      ? "danger"
                      : "primary"
                  }
                  onClick={() => {
                    const m = modal
                    setModal("")
                    if (m === "interest") {
                      go("chat")
                      notify(
                        "Interesse enviado! Combine os detalhes na conversa.",
                      )
                    } else if (m === "confirm") {
                      setConfirmed(true)
                      go("confirmed")
                    } else if (m === "published") go("ads")
                    else if (m === "reviewed") go("games")
                    else if (m === "cancel") {
                      setConfirmed(false)
                      go("games")
                      notify(
                        "Partida cancelada. O time adversário será informado na versão conectada.",
                      )
                    } else if (m.startsWith("delete-")) {
                      setAds(
                        ads.filter((_, i) => i !== Number(m.split("-")[1])),
                      )
                      notify("Anúncio excluído")
                    }
                  }}
                >
                  {modal === "interest"
                    ? "Sim, tenho interesse"
                    : modal === "confirm"
                      ? "Confirmar partida"
                      : modal === "published"
                        ? "Ver meus anúncios"
                        : modal === "reviewed"
                          ? "Voltar aos jogos"
                          : modal === "cancel"
                            ? "Cancelar partida"
                            : "Sim, excluir"}
                </Button>
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  )
}
function Brand() {
  return (
    <div className="brand">
      <div className="brand-symbol">
        <Icon name="ball" size={27} />
      </div>
      <div>
        joga<span>contra</span>
        <small>ENCONTRE. COMBINE. JOGUE.</small>
      </div>
    </div>
  )
}
function Empty({
  icon,
  title,
  text,
  action,
}: {
  icon: IconName
  title: string
  text: string
  action?: ReactNode
}) {
  return (
    <div className="empty-state">
      <Icon name={icon} size={42} />
      <h2>{title}</h2>
      <p>{text}</p>
      {action}
    </div>
  )
}
