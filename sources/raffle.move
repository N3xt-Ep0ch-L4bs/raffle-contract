module raffle::raffle;

use sui::balance::{Balance, zero};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::random::{Self, Random};
use sui::sui::SUI;

const EIncorrectTiCketPrice: u64 = 0;
const ERaffleNotStarted: u64 = 1;
const ERaffleEnded: u64 = 2;
const ERaffleNotEnded: u64 = 3;
const EWinnerAlreadyFound: u64 = 4;
const ENoPlayers: u64 = 5;
const ENotWinner: u64 = 6;

public struct Raffle has key, store {
    id: UID,
    ticket_price: u64,
    start_time: u64,
    end_time: u64,
    creator: address,
    balance: Balance<SUI>,
    players: u64,
    winner: Option<u64>,
}

public struct Ticket has key, store {
    id: UID,
    raffle_id: ID,
    player_index: u64,
}
public struct RaffleCreated has copy, drop {
    raffle_id: ID,
    creator: address,
    ticket_price: u64,
    start_time: u64,
    end_time: u64,
}

public struct TicketBought has copy, drop {
    raffle_id: ID,
    player: address,
    player_index: u64,
}

public struct WinnerChosen has copy, drop {
    raffle_id: ID,
    winner_index: u64,
}

public struct PrizeRedeemed has copy, drop {
    raffle_id: ID,
    winner: address,
    amount: u64,
}

public fun create_raffle(ticket_price: u64, start_time: u64, end_time: u64, ctx: &mut TxContext) {
    let raffle = Raffle {
        id: object::new(ctx),
        ticket_price,
        start_time,
        end_time,
        creator: ctx.sender(),
        balance: zero(),
        players: 0,
        winner: option::none(),
    };

    event::emit(RaffleCreated {
        raffle_id: object::id(&raffle),
        creator: ctx.sender(),
        ticket_price,
        start_time,
        end_time,
    });

    transfer::public_share_object(raffle);
}

public fun buy_ticket(
    raffle: &mut Raffle,
    price: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
): Ticket {
    assert!(coin::value(&price)==raffle.ticket_price, EIncorrectTiCketPrice);
    assert!(raffle.start_time <= clock::timestamp_ms(clock), ERaffleNotStarted);

    assert!(raffle.end_time >clock::timestamp_ms(clock), ERaffleEnded);

    coin::put(&mut raffle.balance, price);

    raffle.players = raffle.players + 1;

    let ticket = Ticket {
        id: object::new(ctx),
        raffle_id: object::id(raffle),
        player_index: raffle.players,
    };

    event::emit(TicketBought {
        raffle_id: object::id(raffle),
        player: ctx.sender(),
        player_index: raffle.players,
    });

    ticket
}

entry fun choose_winner(raffle: &mut Raffle, clock: &Clock, r: &Random, ctx: &mut TxContext) {
    assert!(raffle.end_time <= clock::timestamp_ms(clock), ERaffleNotEnded);
    assert!(raffle.winner == option::none(), EWinnerAlreadyFound);
    assert!(raffle.players > 0, ENoPlayers);

    let mut generator = random::new_generator(r, ctx);
    let winner = random::generate_u64_in_range(&mut generator, 1, raffle.players);
    raffle.winner = option::some(winner);

    event::emit(WinnerChosen {
        raffle_id: object::id(raffle),
        winner_index: winner,
    });
}

public fun winner_redeem_price(ticket: Ticket, raffle: Raffle, ctx: &mut TxContext): Coin<SUI> {
    assert!(raffle.winner.contains(&ticket.player_index), ENotWinner);

    let Ticket { id, raffle_id: _, player_index: _ } = ticket;
    object::delete(id);

    let raffle_id = object::id(&raffle);

    let Raffle {
        id,
        ticket_price: _,
        start_time: _,
        end_time: _,
        creator: _,
        balance,
        players: _,
        winner: _,
    } = raffle;
    object::delete(id);

    let prize = coin::from_balance(balance, ctx);

    event::emit(PrizeRedeemed {
        raffle_id,
        winner: ctx.sender(),
        amount: coin::value(&prize),
    });

    prize
}
