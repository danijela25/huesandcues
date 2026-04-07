const WebSocket = require("ws");
const crypto = require("crypto");

const wss = new WebSocket.Server({ port: 3000 });
const rooms = {};

const MIN_PLAYERS = 2;
const MAX_PLAYERS = 6;
const ROW_LETTERS = "ABCDEFGHIJKLMNOP";

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

function tileCode(x, y) {
  return `${ROW_LETTERS[y]}${x + 1}`;
}

function hsvToRgb(h, s, v) {
  let r, g, b;
  const i = Math.floor(h * 6);
  const f = h * 6 - i;
  const p = v * (1 - s);
  const q = v * (1 - f * s);
  const t = v * (1 - (1 - f) * s);
  switch (i % 6) {
    case 0: r = v; g = t; b = p; break;
    case 1: r = q; g = v; b = p; break;
    case 2: r = p; g = v; b = t; break;
    case 3: r = p; g = q; b = v; break;
    case 4: r = t; g = p; b = v; break;
    case 5: r = v; g = p; b = q; break;
  }
  return { r, g, b };
}

function tileColor(x, y) {
  let hue = (x / 30.0) + (y / 200.0);
  if (hue > 1.0) hue -= 1.0;

  let saturation = 0.35 + y / 22.0;
  if (saturation > 1.0) saturation = 1.0;

  let value = 1.0 - y / 26.0;
  if (value < 0.65) value = 0.65;

  return hsvToRgb(hue, saturation, value);
}

function phaseLabel(phase) {
  switch (phase) {
    case "first_hint": return "Prvi hint";
    case "first_guess": return "Prvo pogađanje";
    case "second_hint": return "Drugi hint";
    case "second_guess": return "Drugo pogađanje";
    case "round_result": return "Rezultat runde";
    default: return phase;
  }
}

function validHintForPhase(hint, phase) {
  const words = hint.trim().split(/\s+/).filter(Boolean);
  if (phase === "first_hint") return words.length === 1;
  if (phase === "second_hint") return words.length === 2;
  return false;
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

function buildGuessOrder(room, reverse=false) {
  const arr = room.players.filter((p) => p.id !== room.players[room.cueGiverIndex].id).map((p) => p.id);
  return reverse ? arr.reverse() : arr;
}

function currentGuesser(room) {
  if (!room.guessOrder || room.currentGuesserIndex == null) return null;
  const id = room.guessOrder[room.currentGuesserIndex];
  return room.players.find((p) => p.id === id) || null;
}

function startNewGame(room) {
  room.status = "playing";
  room.roundNumber = 1;
  room.maxRounds = room.players.length * 2;
  room.cueGiverIndex = 0;
  room.replayVotes = [];
  startRound(room);
}

function resetForReplay(room) {
  room.players.forEach((p) => {
    p.score = 0;
    p.ready = true;
  });
  room.replayVotes = [];
  room.roundNumber = 1;
  room.cueGiverIndex = 0;
  startRound(room);
}

function startRound(room) {
  room.status = "playing";
  room.phase = "first_hint";
  room.currentHint = "";
  room.guessesFirst = {};
  room.guessesSecond = {};
  room.guessOrder = buildGuessOrder(room, false);
  room.currentGuesserIndex = 0;
  room.secretTile = { x: Math.floor(Math.random() * 30), y: Math.floor(Math.random() * 16) };
  const cueGiver = room.players[room.cueGiverIndex];

  broadcast(room, {
    type: "game_start",
    roundNumber: room.roundNumber,
    phaseLabel: phaseLabel(room.phase),
    cueGiverId: cueGiver.id,
    currentGuesserId: "",
    currentGuesserName: "",
    players: room.players.map(playerView),
  });

  send(cueGiver.ws, {
    type: "secret_tile",
    tileX: room.secretTile.x,
    tileY: room.secretTile.y,
    tileCode: tileCode(room.secretTile.x, room.secretTile.y),
    color: tileColor(room.secretTile.x, room.secretTile.y),
  });

  broadcastState(room);
}

function combinedGuesses(room) {
  const map = {};
  Object.values(room.guessesFirst || {}).forEach(g => { map[g.playerId] = g; });
  Object.values(room.guessesSecond || {}).forEach(g => { map[g.playerId] = g; });
  return Object.values(map);
}

function broadcastState(room) {
  const activeGuesser = currentGuesser(room);
  broadcast(room, {
    type: "state_update",
    roundNumber: room.roundNumber,
    phaseLabel: phaseLabel(room.phase),
    cueGiverId: room.players[room.cueGiverIndex].id,
    currentGuesserId: activeGuesser ? activeGuesser.id : "",
    currentGuesserName: activeGuesser ? activeGuesser.name : "",
    hint: room.currentHint,
    players: room.players.map(playerView),
    guesses: combinedGuesses(room),
  });
}

function distance(a, b) {
  return Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));
}

function pointsForGuess(guess, secret) {
  const d = distance(guess, secret);
  if (d === 0) return 3;
  if (d === 1) return 2;
  if (d === 2) return 1;
  return 0;
}

function finishRound(room) {
  room.status = "round_result";
  room.phase = "round_result";
  const roundScores = [];
  const cueGiver = room.players[room.cueGiverIndex];
  let cueBonus = 0;

  room.players.forEach((player) => {
    if (player.id === cueGiver.id) return;
    const first = room.guessesFirst[player.id];
    const second = room.guessesSecond[player.id] || first;
    const guess = second || first;
    const delta = guess ? pointsForGuess({ x: guess.x, y: guess.y }, room.secretTile) : 0;
    player.score += delta;
    roundScores.push({ name: player.name, delta });
    if (delta >= 2) cueBonus += 2;
  });

  cueGiver.score += cueBonus;
  roundScores.push({ name: cueGiver.name + " (Cue Giver)", delta: cueBonus });

  const nextIndex = (room.cueGiverIndex + 1) % room.players.length;
  room.nextCueGiverIndex = nextIndex;
  const nextCue = room.players[nextIndex];

  broadcast(room, {
    type: "round_result",
    correctTile: {
      x: room.secretTile.x,
      y: room.secretTile.y,
      code: tileCode(room.secretTile.x, room.secretTile.y),
      color: tileColor(room.secretTile.x, room.secretTile.y),
    },
    players: room.players.map(playerView),
    roundScores,
    nextCueGiverId: nextCue.id,
    nextCueGiverName: nextCue.name,
  });

  if (room.roundNumber >= room.maxRounds) {
    room.status = "finished";
    broadcast(room, {
      type: "game_over",
      players: room.players.map(playerView).sort((a, b) => b.score - a.score),
      replayVotes: room.replayVotes || [],
    });
  }
}

wss.on("connection", (ws) => {
  ws.playerId = crypto.randomUUID();
  ws.roomCode = null;

  ws.on("message", (message) => {
    let data = null;
    try { data = JSON.parse(message.toString()); } catch { return; }

    if (data.type === "create_room") {
      const code = generateRoomCode();
      const room = {
        code,
        hostId: ws.playerId,
        status: "lobby",
        players: [{ id: ws.playerId, name: data.playerName || "Igrač", ready: false, score: 0, ws }],
        replayVotes: [],
      };
      rooms[code] = room;
      ws.roomCode = code;
      send(ws, { type: "room_created", roomCode: code, playerId: ws.playerId });
      broadcast(room, getLobbyState(room));
      return;
    }

    if (data.type === "join_room") {
      const room = rooms[data.roomCode];
      if (!room) return send(ws, { type: "error", message: "Soba nije pronađena" });
      if (room.status !== "lobby") return send(ws, { type: "error", message: "Igra je već počela" });
      if (room.players.length >= MAX_PLAYERS) return send(ws, { type: "error", message: "Soba je puna" });
      room.players.push({ id: ws.playerId, name: data.playerName || "Igrač", ready: false, score: 0, ws });
      ws.roomCode = room.code;
      send(ws, { type: "joined_room", roomCode: room.code, playerId: ws.playerId });
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
        return send(ws, { type: "error", message: "Nema dovoljno igrača ili nisu svi ready" });
      }
      startNewGame(room);
      return;
    }

    if (data.type === "restart_game_vote") {
      if (room.status !== "finished") return;
      room.replayVotes = room.replayVotes || [];
      if (!room.replayVotes.includes(ws.playerId)) room.replayVotes.push(ws.playerId);
      broadcast(room, { type: "replay_vote_update", replayVotes: room.replayVotes });
      if (room.replayVotes.length >= room.players.length) resetForReplay(room);
      return;
    }

    if (data.type === "next_round_ready") {
      if (room.status !== "round_result") return;
      const nextCue = room.players[room.nextCueGiverIndex];
      if (!nextCue || nextCue.id !== ws.playerId) return;
      if (room.roundNumber >= room.maxRounds) return;
      room.roundNumber += 1;
      room.cueGiverIndex = room.nextCueGiverIndex;
      startRound(room);
      return;
    }

    if (room.status !== "playing") return;
    const cueGiver = room.players[room.cueGiverIndex];

    if (data.type === "submit_hint") {
      if (ws.playerId !== cueGiver.id) return;
      if (!(room.phase === "first_hint" || room.phase === "second_hint")) return;
      room.currentHint = (data.hint || "").trim();
      if (room.currentHint === "") return;
      if (!validHintForPhase(room.currentHint, room.phase)) {
        return send(ws, { type: "error", message: room.phase === "first_hint" ? "Prvi hint mora imati tačno jednu reč." : "Drugi hint mora imati tačno dve reči." });
      }
      room.currentGuesserIndex = 0;
      if (room.phase === "first_hint") {
        room.guessOrder = buildGuessOrder(room, false);
        room.phase = "first_guess";
      } else {
        room.guessOrder = buildGuessOrder(room, true);
        room.phase = "second_guess";
      }
      broadcastState(room);
      return;
    }

    if (data.type === "select_tile") {
      if (ws.playerId === cueGiver.id) return;
      if (!(room.phase === "first_guess" || room.phase === "second_guess")) return;
      const activeGuesser = currentGuesser(room);
      if (!activeGuesser || activeGuesser.id !== ws.playerId) return;
      const player = room.players.find((p) => p.id === ws.playerId);
      if (!player) return;
      const guess = { playerId: player.id, name: player.name, x: Number(data.tileX), y: Number(data.tileY) };
      if (room.phase === "first_guess") {
        room.guessesFirst[player.id] = guess;
        room.currentGuesserIndex += 1;
        if (room.currentGuesserIndex >= room.guessOrder.length) room.phase = "second_hint";
      } else {
        room.guessesSecond[player.id] = guess;
        room.currentGuesserIndex += 1;
        if (room.currentGuesserIndex >= room.guessOrder.length) {
          finishRound(room);
          return;
        }
      }
      broadcastState(room);
      return;
    }
  });

  ws.on("close", () => {
    const room = rooms[ws.roomCode];
    if (!room) return;
    room.players = room.players.filter((p) => p.id !== ws.playerId);
    room.replayVotes = (room.replayVotes || []).filter((id) => id !== ws.playerId);
    if (room.players.length === 0) {
      delete rooms[ws.roomCode];
      return;
    }
    if (room.hostId === ws.playerId) room.hostId = room.players[0].id;
    broadcast(room, getLobbyState(room));
  });
});

console.log("Server radi na ws://127.0.0.1:3000");