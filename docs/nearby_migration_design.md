# Nearby Connections migration — design

## Kontekst

Obecnie Tab Station ↔ OP13 Recorder komunikują się przez:
- **WebSocket** (shelf server na Tab port 8080, client na Recorder) — event_config,
  start/stop, status, progress
- **HTTP POST** `/upload` (shelf endpoint) — transfer MP4 po nagraniu

Problem: WS wymaga wspólnej sieci WiFi ze stabilnym routingiem. Hotspoty LTE
(telefon dziadka, przenośne) są niestabilne — WS zrywa się co 10s, Station<->
Recorder traci sync, event_config nie dociera.

Rozwiązanie: **Nearby Connections API (Google)** — P2P transport hybrid
BT + WiFi Direct. Nie wymaga routera/hotspotu dla Tab↔OP13.

## Package

- `nearby_connections` 4.3.0 (Android-only, 144 likes, 160 pub points)
- Min Android API: ~21 (L). OP13 + Tab = API 30+ więc OK.
- Wymagane permissions: `BLUETOOTH`, `BLUETOOTH_ADVERTISE` (A12+),
  `BLUETOOTH_CONNECT` (A12+), `BLUETOOTH_SCAN` (A12+),
  `ACCESS_FINE_LOCATION`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`
- Quirk: GPS musi być ON (Nearby używa scan wymagający location permission)

## Architektura

```
┌──────────────────┐                      ┌──────────────────┐
│   Tab Station    │                      │ OP13 Recorder    │
│                  │                      │                  │
│ NearbyServer:    │◄──── Nearby P2P ────►│ NearbyClient:    │
│ - advertising    │  BT+WiFiDirect hybrid│ - discovery      │
│ - accept conn    │  (auto upgrade to    │ - connect        │
│ - onBytes()      │   WiFi when ready)   │ - sendBytes()    │
│ - onFile()       │                      │ - sendFile()     │
└──────────────────┘                      └──────────────────┘
```

- **Service ID**: `pl.akces360.booth.nearby.v1`
- **Strategy**: `P2P_POINT_TO_POINT` (1:1, jedna para Tab+OP13)
- **Auto-accept**: tak (trusted devices, w sali rzadko drugie boothy)

## Mapowanie message types

Zachowujemy `WireMsg.*` stringi. Transport się zmienia, protocol ten sam.

| Kierunek | Typ | Obecnie | Po migracji |
|----------|-----|---------|-------------|
| Tab→OP13 | event_config | WS JSON | sendBytesPayload(jsonEncode(msg)) |
| Tab→OP13 | start_recording | WS | sendBytesPayload |
| Tab→OP13 | stop_recording | WS | sendBytesPayload |
| Tab→OP13 | ping | WS | Nearby ma wewnętrzny keepalive, usuwamy |
| OP13→Tab | recorder_status | WS | sendBytesPayload |
| OP13→Tab | recording_started | WS | sendBytesPayload |
| OP13→Tab | recording_progress | WS | sendBytesPayload |
| OP13→Tab | recording_stopped | WS | sendBytesPayload |
| OP13→Tab | processing_progress | WS | sendBytesPayload |
| OP13→Tab | processing_done | WS | sendBytesPayload |
| OP13→Tab | upload_progress | WS | sendBytesPayload |
| OP13→Tab | error | WS | sendBytesPayload |
| OP13→Tab | **MP4 upload** | HTTP POST /upload | **sendFilePayload(File)** |

### File transfer specjalnie

Current: Recorder HTTP POST 20-50MB MP4 → Station przyjmuje przez shelf.
After: Recorder `Nearby.sendFilePayload(File)` → Station dostaje callback
`onPayloadReceived` z payload type FILE → kopiuje do `received/` folder.

Prekursor: przed sendFilePayload wysyłamy bytes message `{type: file_incoming,
short_name: '...', size: N}` żeby Station wiedziała kontekst (link do job).

## Nowe pliki

- `station/lib/services/nearby_server.dart` — NearbyServer class (advertising,
  accept, receive bytes + files, broadcast to handlers)
- `recorder/lib/services/nearby_client.dart` — NearbyClient class (discovery,
  connect, send bytes + files, reconnect logic)
- Shared helpers: `_SERVICE_ID`, `_STRATEGY`, message serialization

## Fallback / hybrid mode

Nie robimy. Decyzja: **100% Nearby** dla Tab↔OP13. LocalServer/WS kod usunięty
z obu apek. Mniej kodu, mniej bugów, spójny UX.

Station dalej ma HTTP dla:
- Upload do Pi (booth.akces360.pl) → nic się nie zmienia, internet route
- Serwowanie lokalnych filmów goście (`/local/<short>`) → zostaje dla
  offline fallback PendingUploads

## Permissions UX

Pierwsze uruchomienie na nowym urządzeniu:
1. App Settings → Settings → Permission dialogs (BT, Location)
2. Tab: "Ustaw jako Station" (advertising)
3. OP13: auto-discover → pokazuje listę booth-ów w zasięgu → user tap → pair
4. Pair OK: zapisany Service ID w prefs, autoconnect przy następnym starcie

## Pairing flow

```
Tab (Station) start:
  NearbyServer.startAdvertising(
    userName: "AkcesBooth-Tab",
    strategy: Strategy.P2P_POINT_TO_POINT,
    onConnectionInitiated: (id, info) => acceptConnection(id),
    onConnectionResult: (id, status) => logStatus,
    onDisconnected: (id) => cleanup,
  )

OP13 (Recorder) start:
  NearbyClient.startDiscovery(
    strategy: Strategy.P2P_POINT_TO_POINT,
    onEndpointFound: (id, name, serviceId) => requestConnection(id),
    onEndpointLost: (id) => reconnect,
  )
```

## Testy

1. Pairing test w RS: Tab advertising + OP13 discovery → widzi się po <10s
2. Bytes roundtrip: Tab → event_config → OP13, OP13 → recorder_status → Tab
3. File transfer: OP13 → 30MB MP4 → Tab, progress callback działa
4. Disconnect/reconnect: wyłącz Tab WiFi → Nearby powinno przeprawić via BT
5. Battery: 2h idle + 10 nagrań = jaka bateria

## Timeline

- Etap 1 (dzisiaj): exploration + design (ten doc) + package w pubspec
- Etap 2 (~2 dni): NearbyServer + NearbyClient classes, bytes messaging
- Etap 3 (~2 dni): File transfer integration, replace HTTP upload
- Etap 4 (~1 dzień): Permissions UX + pairing UI
- Etap 5 (~1 dzień): E2E test z fotobudką dziadka

~7-10 h roboczych, termin 13.06 Ola = 7 tyg, zdążymy z testami.
