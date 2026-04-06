const WebSocket = require("ws");
const crypto = require("crypto");

const wss = new WebSocket.Server({ port: 3000 });
const rooms = {};

const MIN_PLAYERS = 2;
const MAX_PLAYERS = 6;

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data));
}

function broadcast(room, data) {
  room.players.forEach((p) => send(p.ws, data));
}

function generateRoomCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return rooms[code] ? generateRoomCode() : code;
}

function playerView(player) {
  return { id: player.id, name: player.name, ready: player.ready, score: player.score };
}

function getLobbyState(room) {
  return {
    type: "lobby_state",
    roomCode: room.code,
    hostId: room.hostId,
    canStart: room.players.length >= MIN_PLAYERS && room.players.every((p) => p.ready),
    players: room.players.map(playerView),
  };
}

function startNewGame(room) {
  room.status = "playing";
  room.roundNumber = 1;
  room.maxRounds = room.players.length;
  room.cueGiverIndex = 0;
  startRound(room);
}

function startRound(room) {
  room.phase = "first_hint";
  room.currentHint = "";
  room.guessesFirst = {};
  room.guessesSecond = {};
  room.secretTile = { x: Math.floor(Math.random() * 30), y: Math.floor(Math.random() * 16) };
  const cueGiver = room.players[room.cueGiverIndex];

  broadcast(room, {
    type: "game_start",
    roundNumber: room.roundNumber,
    phase: room.phase,
    cueGiverId: cueGiver.id,
    players: room.players.map(playerView),
  });

  send(cueGiver.ws, { type: "secret_tile", tileX: room.secretTile.x, tileY: room.secretTile.y });
  broadcastState(room);
}

function broadcastState(room) {
  const guesses = [];
  const source = room.phase === "second_guess" ? room.guessesSecond : room.guessesFirst;
  Object.values(source).forEach((g) => guesses.push(g));

  broadcast(room, {
    type: "state_update",
    roundNumber: room.roundNumber,
    phase: room.phase,
    cueGiverId: room.players[room.cueGiverIndex].id,
    hint: room.currentHint,
    players: room.players.map(playerView),
    guesses,
  });
}

function distance(a, b) {
  return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
}

function pointsForGuess(guess, secret) {
  const d = distance(guess, secret);
  if (d === 0) return 3;
  if (d <= 2) return 2;
  if (d <= 4) return 1;
  return 0;
}

function finishRound(room) {
  const roundScores = [];
  const cueGiver = room.players[room.cueGiverIndex];

  room.players.forEach((player) => {
    if (player.id === cueGiver.id) return;
    const first = room.guessesFirst[player.id];
    const second = room.guessesSecond[player.id] || first;
    const guess = second || first;
    const delta = guess ? pointsForGuess({ x: guess.x, y: guess.y }, room.secretTile) : 0;
    player.score += delta;
    roundScores.push({ name: player.name, delta });
    if (delta >= 2) cueGiver.score += 1;
  });

  roundScores.push({ name: cueGiver.name + " (Cue Giver bonus)", delta: 0 });

  broadcast(room, {
    type: "round_result",
    correctTile: room.secretTile,
    players: room.players.map(playerView),
    roundScores,
  });

  if (room.roundNumber >= room.maxRounds) {
    room.status = "finished";
    broadcast(room, {
      type: "game_over",
      players: room.players.map(playerView).sort((a, b) => b.score - a.score),
    });
    return;
  }

  room.roundNumber += 1;
  room.cueGiverIndex = (room.cueGiverIndex + 1) % room.players.length;
  setTimeout(() => {
    if (rooms[room.code] && rooms[room.code].status !== "finished") startRound(room);
  }, 2500);
}

function allGuessersSubmitted(room, which) {
  const target = room.players.length - 1;
  const map = which === "first" ? room.guessesFirst : room.guessesSecond;
  return Object.keys(map).length >= target;
}

wss.on("connection", (ws) => {
  ws.playerId = crypto.randomUUID();
  ws.roomCode = null;

  ws.on("message", (message) => {
    let data = null;
    try { data = JSON.parse(message.toString()); } catch { return; }

    if (data.type === "create_room") {
      const code = generateRoomCode();
      const room = { code, hostId: ws.playerId, status: "lobby", players: [{ id: ws.playerId, name: data.playerName || "Igrac", ready: false, score: 0, ws }] };
      rooms[code] = room;
      ws.roomCode = code;
      send(ws, { type: "room_created", roomCode: code, playerId: ws.playerId });
      broadcast(room, getLobbyState(room));
      return;
    }

    if (data.type === "join_room") {
      const room = rooms[data.roomCode];
      if (!room) return send(ws, { type: "error", message: "Soba nije pronadjena" });
      if (room.status !== "lobby") return send(ws, { type: "error", message: "Igra je vec pocela" });
      if (room.players.length >= MAX_PLAYERS) return send(ws, { type: "error", message: "Soba je puna" });
      room.players.push({ id: ws.playerId, name: data.playerName || "Igrac", ready: false, score: 0, ws });
      ws.roomCode = room.code;
      broadcast(room, getLobbyState(room));
      return;
    }

    const room = rooms[ws.roomCode];
    if (!room) return;

    if (data.type === "player_ready") {
      const player = room.players.find((p) => p.id === ws.playerId);
      if (!player) return;
      player.ready = !!data.ready;
      broadcast(room, getLobbyState(room));
      return;
    }

    if (data.type === "start_game") {
      if (room.hostId !== ws.playerId) return;
      if (!(room.players.length >= MIN_PLAYERS && room.players.every((p) => p.ready))) {
        return send(ws, { type: "error", message: "Nema dovoljno igraca ili nisu svi ready" });
      }
      startNewGame(room);
      return;
    }

    if (room.status !== "playing") return;
    const cueGiver = room.players[room.cueGiverIndex];

    if (data.type === "submit_hint") {
      if (ws.playerId !== cueGiver.id) return;
      if (!(room.phase === "first_hint" || room.phase === "second_hint")) return;
      room.currentHint = (data.hint || "").trim();
      if (room.currentHint === "") return;
      room.phase = room.phase === "first_hint" ? "first_guess" : "second_guess";
      broadcastState(room);
      return;
    }

    if (data.type === "select_tile") {
      if (ws.playerId === cueGiver.id) return;
      if (!(room.phase === "first_guess" || room.phase === "second_guess")) return;
      const player = room.players.find((p) => p.id === ws.playerId);
      if (!player) return;
      const guess = { playerId: player.id, name: player.name, x: Number(data.tileX), y: Number(data.tileY) };

      if (room.phase === "first_guess") {
        room.guessesFirst[player.id] = guess;
        if (allGuessersSubmitted(room, "first")) room.phase = "second_hint";
      } else {
        room.guessesSecond[player.id] = guess;
        if (allGuessersSubmitted(room, "second")) {
          finishRound(room);
          return;
        }
      }

      broadcastState(room);
    }
  });

  ws.on("close", () => {
    const room = rooms[ws.roomCode];
    if (!room) return;
    room.players = room.players.filter((p) => p.id !== ws.playerId);
    if (room.players.length === 0) { delete rooms[ws.roomCode]; return; }
    if (room.hostId === ws.playerId) room.hostId = room.players[0].id;
    broadcast(room, getLobbyState(room));
  });
});

console.log("Server radi na ws://127.0.0.1:3000");
