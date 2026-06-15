# Hues and Cues 

Hues and Cues je multiplayer igra inspirisana društvenom igrom pogađanja boja, razvijena kao studentski projekat.  
Igrači se povezuju u zajedničku sobu pomoću koda sobe i kroz asocijacije pokušavaju da pogode tačnu boju na tabli.

Jedan igrač u svakoj rundi dobija ulogu *Cue Giver-a* i vidi skrivenu boju.  
Njegov zadatak je da ostalim igračima daje kratke tekstualne hintove koji će ih navesti da pogode pravo polje na tabli.

## Glavne funkcionalnosti

- Kreiranje i pridruživanje sobama pomoću room code-a
- Multiplayer komunikacija u realnom vremenu
- Sistem uloga i smenjivanje Cue Giver-a
- Prvo i drugo pogađanje
- Bodovanje igrača
- Prikaz rezultata nakon svake runde
- Vizuelni prikaz tačne oblasti i pogodaka
- Lobby sistem sa ready statusima

## Korišćene tehnologije

### Client
- Godot
- GDScript

### Server
- Node.js
- WebSocket (`ws`)

## Struktura projekta

```text
huesandcues/
├── client/        # Godot projekat
├── server/        # WebSocket server
├── README.md
└── .gitignore