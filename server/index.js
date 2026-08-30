const WebSocket = require("ws");
const crypto = require("crypto");

const PORT = process.env.PORT || 3000;
const wss = new WebSocket.Server({ port: PORT });
const rooms = {};

const MIN_PLAYERS = 3;
const MAX_PLAYERS = 6;
const TURN_TIME = 60 * 1000;
const RECONNECT_TIME = 2 * 60 * 1000;
const NEXT_ROUND_READY_TIME = 45 * 1000;
const ROW_LETTERS = "ABCDEFGHIJKLMNOP";
console.log("Najnovija verzija servera radi na portu " + PORT);

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

function buildGuessOrder(room, reverse = false) {
  const arr = room.players.filter((p) => p.id !== room.players[room.cueGiverIndex].id).map((p) => p.id);
  return reverse ? arr.reverse() : arr;
}

function currentGuesser(room) {
  if (!room.guessOrder || room.currentGuesserIndex == null) return null;
  const id = room.guessOrder[room.currentGuesserIndex];
  return room.players.find((p) => p.id === id) || null;
}
function clearActionTimer(room) {
  if (!room) return;

  if (room.actionTimer) {
    clearTimeout(room.actionTimer);
    room.actionTimer = null;
  }

  room.actionDeadline = null;
}

function startActionTimer(room, duration = TURN_TIME) {

  if (!room || room.status !== "playing") return;

  clearActionTimer(room);

  if (
    room.frozen &&
    room.disconnectedPlayers &&
    room.disconnectedPlayers.size > 0
  ) {
    room.remainingActionTime = duration;
    return;
  }

  if (
    room.frozen &&
    (!room.disconnectedPlayers ||
      room.disconnectedPlayers.size === 0)
  ) {
    room.frozen = false;
  }
  room.remainingActionTime = duration;
  room.actionDeadline = Date.now() + duration;
  console.log(
    "START TIMER:",
    room.code,
    room.phase,
    duration
  );
  room.actionTimer = setTimeout(() => {
    room.actionTimer = null;
    room.actionDeadline = null;

    handleActionTimeout(room);
  }, duration);
}

function pauseActionTimer(room) {
  if (!room) return;

  if (room.actionTimer && room.actionDeadline != null) {
    room.remainingActionTime = Math.max(
      1,
      room.actionDeadline - Date.now()
    );

    clearTimeout(room.actionTimer);

    room.actionTimer = null;
    room.actionDeadline = null;
  }
}

function resumeActionTimer(room) {
  if (!room || room.frozen || room.status !== "playing") return;

  const duration =
    room.remainingActionTime != null &&
      room.remainingActionTime > 0
      ? room.remainingActionTime
      : TURN_TIME;

  startActionTimer(room, duration);
}
function handleActionTimeout(room) {
  console.log(
    "TIMEOUT:",
    room.code,
    room.phase,
    "frozen=",
    room.frozen,
    "status=",
    room.status
  );
  if (!room) {
    return;
  }

  if (room.status !== "playing") {
    return;
  }

  // Ako je igra zamrznuta zbog disconnect-a,
  // ne prelazi se na sledeci potez
  if (room.frozen) {
    return;
  }


  if (room.phase === "first_hint") {
    console.log("PRVI HINT ISTEKAO - PRELAZIM NA FIRST_GUESS");
    room.firstHintTimedOut = true;

    room.currentHint =
      "/ - vreme za hint je isteklo";

    room.guessOrder =
      buildGuessOrder(room, false);

    room.currentGuesserIndex = 0;

    room.phase = "first_guess";

    broadcastState(room);

    startActionTimer(room);

    return;
  }



  if (room.phase === "first_guess") {

    // Nema guess-a za njega -> automatski 0 poena
    // Samo prelazimo na sledeceg
    room.currentGuesserIndex += 1;

    // Ako su svi zavrsili prvo pogadjanje
    if (
      room.currentGuesserIndex >=
      room.guessOrder.length
    ) {

      room.phase = "second_hint";

      room.currentGuesserIndex = 0;

      room.guessOrder = [];
    }

    broadcastState(room);

    startActionTimer(room);

    return;
  }



  if (room.phase === "second_hint") {

    room.secondHintTimedOut = true;

    room.currentHint =
      "/ - vreme za hint je isteklo";

    room.guessOrder =
      buildGuessOrder(room, true);

    room.currentGuesserIndex = 0;

    room.phase = "second_guess";

    broadcastState(room);

    startActionTimer(room);

    return;
  }


  if (room.phase === "second_guess") {

    room.currentGuesserIndex += 1;

    // Ako su svi zavrsili drugo pogadjanje,
    // runda se zavrsava
    if (
      room.currentGuesserIndex >=
      room.guessOrder.length
    ) {

      finishRound(room);

      return;
    }

    broadcastState(room);

    startActionTimer(room);

    return;
  }
}

function startNewGame(room) {
  room.status = "playing";
  room.roundNumber = 1;
  room.maxRounds = room.players.length * 2;
  room.cueGiverIndex = 0;
  startRound(room);
}



function startRound(room) {
  room.status = "playing";
  room.phase = "first_hint";
  room.currentHint = "";
  room.guessesFirst = {};
  room.guessesSecond = {};
  room.firstHintTimedOut = false;
  room.secondHintTimedOut = false;
  room.remainingActionTime = TURN_TIME;
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
    tileCode: tileCode(room.secretTile.x, room.secretTile.y)
  });

  broadcastState(room);
  startActionTimer(room);
}

function combinedGuesses(room) {
  const result = [];

  Object.values(room.guessesFirst || {}).forEach(g => {
    result.push({ ...g, type: "first" });
  });

  Object.values(room.guessesSecond || {}).forEach(g => {
    result.push({ ...g, type: "second" });
  });

  return result;
}

function broadcastState(room) {
  let activeGuesser = null;

  if (
    room.phase === "first_guess" ||
    room.phase === "second_guess"
  ) {
    activeGuesser = currentGuesser(room);
  }

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
  clearActionTimer(room);
  room.status = "round_result";
  room.phase = "round_result";
  const roundScores = [];
  const cueGiver = room.players[room.cueGiverIndex];
  let cueBonus = 0;

  room.players.forEach((player) => {
    if (player.id === cueGiver.id) return;
    const first = room.guessesFirst[player.id];
    const second = room.guessesSecond[player.id];
    let delta = 0;
    let delta1 = 0;
    let delta2 = 0;
    if (first) {
      delta1 = pointsForGuess({ x: first.x, y: first.y }, room.secretTile);
      if (delta1 >= 2 && !room.firstHintTimedOut) {
        cueBonus += 2;
      }
    }

    if (second) {
      delta2 = pointsForGuess({ x: second.x, y: second.y }, room.secretTile);
      if (delta2 >= 2 && !room.secondHintTimedOut) cueBonus += 2;
    }
    delta = delta1 + delta2;
    player.score += delta;
    roundScores.push({ name: player.name, delta });

  });

  cueGiver.score += cueBonus;
  roundScores.push({ name: cueGiver.name + " (Cue Giver)", delta: cueBonus });

  const nextIndex = (room.cueGiverIndex + 1) % room.players.length;
  room.nextCueGiverIndex = nextIndex;
  const nextCue = room.players[nextIndex];
  if (room.nextRoundReadyTimer) {
    clearTimeout(room.nextRoundReadyTimer);
    room.nextRoundReadyTimer = null;
  }

  broadcast(room, {
    type: "round_result",
    correctTile: {
      x: room.secretTile.x,
      y: room.secretTile.y,
      code: tileCode(room.secretTile.x, room.secretTile.y),

    },
    players: room.players.map(playerView),
    roundScores,
    nextCueGiverId: nextCue.id,
    nextCueGiverName: nextCue.name,
    guesses: combinedGuesses(room)
  });

  if (room.roundNumber < room.maxRounds) {

    room.nextRoundReadyTimer = setTimeout(() => {

      room.nextRoundReadyTimer = null;

      if (room.status !== "round_result") {
        return;
      }

      const nextCue =
        room.players[room.nextCueGiverIndex];

      if (!nextCue) {
        return;
      }

      console.log(
        "CUE GIVER READY TIMEOUT:",
        nextCue.name
      );

      room.roundNumber += 1;
      room.cueGiverIndex =
        room.nextCueGiverIndex;

      startRound(room);

    }, NEXT_ROUND_READY_TIME);
  }
}
  function removePlayerFromRoom(ws) {
    const room = rooms[ws.roomCode];

    if (!room) {
      return;
    }

    const leavingPlayer = room.players.find(
      p => p.id === ws.playerId
    );

    const leavingName =
      leavingPlayer ? leavingPlayer.name : "Igrač";


    clearActionTimer(room);


    // ugasi sve reconnect timere
    if (room.reconnectTimers) {
      Object.values(room.reconnectTimers).forEach(timer => {
        clearTimeout(timer);
      });
    }


    broadcast(room, {
      type: "player_left",
      message:
        leavingName +
        " je napustio/la sobu. Igra je prekinuta."
    });


    delete rooms[room.code];
  }
  function handleUnexpectedDisconnect(ws) {
    const room = rooms[ws.roomCode];

    if (!room) {
      return;
    }

    const player = room.players.find(
      p => p.id === ws.playerId
    );

    if (!player) {
      return;
    }

    // Ako je vec registrovan kao diskonektovan,
    // ne pokreci sve ponovo
    if (room.disconnectedPlayers.has(player.id)) {
      return;
    }

    // Registruj diskonektovanog igraca
    room.disconnectedPlayers.add(player.id);

    // Zamrzni igru i pauziraj trenutni potez
    if (!room.frozen) {
      room.frozen = true;
      pauseActionTimer(room);
    }

    // Svim igracima javi da cekamo 2 minuta
    broadcast(room, {
      type: "game_frozen",
      playerId: player.id,
      playerName: player.name,
      reconnectSeconds: 120,
      message:
        player.name +
        " je napustio/la sobu.\n" +
        "Čekamo 2 minuta da se vrati..."
    });

    // Pokreni reconnect timer od 2 minuta
    room.reconnectTimers[player.id] = setTimeout(() => {

      // Ako se u medjuvremenu vratio, ne radi nista
      if (!room.disconnectedPlayers.has(player.id)) {
        return;
      }

      // Nije se vratio -> kraj igre
      broadcast(room, {
        type: "player_left",
        playerId: player.id,
        playerName: player.name,
        message:
          player.name +
          " se nije vratio. Kraj igre."
      });

      clearActionTimer(room);

      Object.values(room.reconnectTimers).forEach(timer => {
        clearTimeout(timer);
      });

      delete rooms[room.code];

    }, RECONNECT_TIME);
  }
  wss.on("connection", (ws) => {
    ws.playerId = crypto.randomUUID();
    ws.roomCode = null;

    ws.on("message", (message) => {
      let data = null;
      try { data = JSON.parse(message.toString()); } catch { return; }
      if (data.type === "reconnect") {
        const room = rooms[data.roomCode];

        if (!room) {
          return send(ws, {
            type: "reconnect_failed",
            message: "Soba više ne postoji."
          });
        }


        const player = room.players.find(
          p => p.id === data.playerId
        );


        if (
          !player ||
          !room.disconnectedPlayers.has(data.playerId)
        ) {
          return send(ws, {
            type: "reconnect_failed",
            message: "Povratak u igru nije moguć."
          });
        }


        // novi socket dobija stari playerId
        ws.playerId = player.id;
        ws.roomCode = room.code;

        player.ws = ws;


        // ugasi njegov reconnect timeout
        if (room.reconnectTimers[player.id]) {
          clearTimeout(room.reconnectTimers[player.id]);
          delete room.reconnectTimers[player.id];
        }


        room.disconnectedPlayers.delete(player.id);

        send(ws, {
          type: "reconnected",
          roomCode: room.code,
          playerId: player.id,
          status: room.status
        });


        if (room.status === "playing") {

          let activeGuesser = null;

          if (
            room.phase === "first_guess" ||
            room.phase === "second_guess"
          ) {
            activeGuesser = currentGuesser(room);
          }

          send(ws, {
            type: "state_update",
            roundNumber: room.roundNumber,
            phaseLabel: phaseLabel(room.phase),

            cueGiverId:
              room.players[room.cueGiverIndex].id,

            currentGuesserId:
              activeGuesser ? activeGuesser.id : "",

            currentGuesserName:
              activeGuesser ? activeGuesser.name : "",

            hint: room.currentHint,

            players:
              room.players.map(playerView),

            guesses:
              combinedGuesses(room)
          });

        } else if (room.status === "lobby") {

          send(
            ws,
            getLobbyState(room)
          );
        }


        //vrati celo trenutno stanje igracu koji se reconnectovao, ukljucujuci i tajni tile ako je on cue giver

        if (
          room.status === "playing" &&
          room.players[room.cueGiverIndex] &&
          room.players[room.cueGiverIndex].id === player.id
        ) {

          send(ws, {
            type: "secret_tile",
            tileX: room.secretTile.x,
            tileY: room.secretTile.y,
            tileCode: tileCode(
              room.secretTile.x,
              room.secretTile.y
            )
          });
        }


        // Ako su se svi koji su izgubili vezu vratili
        if (room.disconnectedPlayers.size === 0) {
          room.frozen = false;

          broadcast(room, {
            type: "game_resumed",
            playerId: player.id,
            playerName: player.name,
            message:
              player.name +
              " se vratio. Igra se nastavlja."
          });

          if (room.status === "playing") {
            broadcastState(room);
            resumeActionTimer(room);
          }
        }

        return;
      }
      if (data.type === "create_room") {
        const code = generateRoomCode();
        const room = {
          code,
          hostId: ws.playerId,
          status: "lobby",
          players: [{ id: ws.playerId, name: data.playerName || "Igrač", ready: false, score: 0, ws }],
          frozen: false,
          disconnectedPlayers: new Set(),
          reconnectTimers: {},

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



      if (data.type === "leave_room") {
        removePlayerFromRoom(ws);
        return;
      }
      const room = rooms[ws.roomCode];
      if (!room) return;
      if (room.frozen) {
        return;
      }
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



      if (data.type === "next_round_ready") {

        if (room.status !== "round_result") {
          return;
        }

        const nextCue =
          room.players[room.nextCueGiverIndex];

        if (
          !nextCue ||
          nextCue.id !== ws.playerId
        ) {
          return;
        }

        if (room.roundNumber >= room.maxRounds) {
          return;
        }


        if (room.nextRoundReadyTimer) {
          clearTimeout(room.nextRoundReadyTimer);
          room.nextRoundReadyTimer = null;
        }


        room.roundNumber += 1;

        room.cueGiverIndex =
          room.nextCueGiverIndex;

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
        //  console.log("PHASE AFTER HINT:", room.phase);
        broadcastState(room);
        startActionTimer(room);
        return;
      }

      if (data.type === "select_tile") {
        //  console.log("SELECT_TILE", {
        //  phase: room.phase,
        // playerId: ws.playerId,
        // tileX: data.tileX,
        // tileY: data.tileY
        //});
        if (ws.playerId === cueGiver.id) return;
        if (!(room.phase === "first_guess" || room.phase === "second_guess")) return;
        const activeGuesser = currentGuesser(room);
        if (!activeGuesser || activeGuesser.id !== ws.playerId) return;
        const player = room.players.find((p) => p.id === ws.playerId);
        if (!player) return;
        const tileX = Number(data.tileX);
        const tileY = Number(data.tileY);
        if (
          !Number.isInteger(tileX) ||
          !Number.isInteger(tileY) ||
          tileX < 0 || tileX >= 30 ||
          tileY < 0 || tileY >= 16
        ) {
          return send(ws, {
            type: "error",
            message: "Neispravno polje"
          });
        }

        const allGuesses = [
          ...Object.values(room.guessesFirst || {}),
          ...Object.values(room.guessesSecond || {})
        ];

        if (allGuesses.some(g => g.x === tileX && g.y === tileY)) {
          return send(ws, { type: "error", message: "Ovo polje je već zauzeto" });
        }

        if (room.phase === "second_guess") {
          const first = room.guessesFirst[player.id];
          if (first && first.x === tileX && first.y === tileY) {
            return send(ws, { type: "error", message: "Ne možeš isto polje dva puta" });
          }
        }
        const guess = { playerId: player.id, name: player.name, x: tileX, y: tileY };
        if (room.phase === "first_guess") {
          room.guessesFirst[player.id] = guess;
          room.currentGuesserIndex += 1;

          if (
            room.currentGuesserIndex >=
            room.guessOrder.length
          ) {
            room.phase = "second_hint";
            room.currentGuesserIndex = 0;
            room.guessOrder = [];
          }

        } else {

          room.guessesSecond[player.id] = guess;
          room.currentGuesserIndex += 1;

          if (
            room.currentGuesserIndex >=
            room.guessOrder.length
          ) {
            finishRound(room);
            return;
          }
        }

        broadcastState(room);
        startActionTimer(room);
        return;
      }
    });

    ws.on("close", () => {
      handleUnexpectedDisconnect(ws);
    });
  });

