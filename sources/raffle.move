module raffle::raffle;

use sui::{
    balance::{Self, Balance},
    clock::{Self, Clock},
    coin::{Self, Coin},
    event,
    random::{Self, Random}
};

const EIncorrectTiCketPrice: u64 = 0;
const ERaffleNotStarted: u64 = 1;
const ERaffleEnded: u64 = 2;
const ERaffleNotEnded: u64 = 3;
const EWinnerAlreadyFound: u64 = 4;
const ENoPlayers: u64 = 5;
const ENotWinner: u64 = 6;
const ERaffleNotEmpty: u64 = 7;
const EBalanceNotZero: u64 = 8;
const EAdminCapRaffleMismatch: u64 = 9;

public struct Raffle<phantom T> has key{
    id: UID,
    ticket_price: u64,
    start_time: u64,
    end_time: u64,
    creator: address,
    balance: Balance<T>,
    players: u64,
    winner: Option<u64>
}

public struct Ticket has key, store{
    id: UID,
    raffle_id: ID,
    player_index: u64
}

public struct AdminCap has key, store{
    id: UID,
    raffle_id: ID
}

public struct RaffleCreated has copy, drop{
    raffle_id: ID,
    creator: address,
    ticket_price: u64,
    start_time: u64,
    end_time: u64
}

public struct TicketBought has copy, drop{
    raffle_id: ID,
    player: address,
    player_index: u64
}

public struct WinnerChosen has copy, drop{
    raffle_id: ID,
    winner_index: u64
}

public struct PrizeRedeemed has copy, drop{
    raffle_id: ID,
    winner: address,
    amount: u64
}

#[allow(lint(self_transfer))]
public fun create_raffle<T>(ticket_price: u64, start_time: u64, end_time: u64, ctx: &mut TxContext){
    let raffle = Raffle<T> {
        id: object::new(ctx),
        ticket_price,
        start_time,
        end_time,
        creator: ctx.sender(),
        balance: balance::zero<T>(),
        players: 0,
        winner: option::none()
    };
    let admin_cap = AdminCap {
        id: object::new(ctx),
        raffle_id: object::id(&raffle)
    };

    event::emit(RaffleCreated {
        raffle_id: object::id(&raffle),
        creator: ctx.sender(),
        ticket_price,
        start_time,
        end_time
    });

    transfer::share_object(raffle);
    transfer::public_transfer(admin_cap, ctx.sender());
}

#[allow(lint(self_transfer))]
public fun buy_ticket<T>(raffle: &mut Raffle<T>, price: Coin<T>, clock: &Clock, ctx: &mut TxContext){
    assert!(coin::value(&price) == raffle.ticket_price, EIncorrectTiCketPrice);
    assert!(raffle.start_time <= clock::timestamp_ms(clock), ERaffleNotStarted);
    assert!(raffle.end_time > clock::timestamp_ms(clock), ERaffleEnded);

    coin::put(&mut raffle.balance, price);

    raffle.players = raffle.players + 1;

    let ticket = Ticket {
        id: object::new(ctx),
        raffle_id: object::id(raffle),
        player_index: raffle.players
    };

    event::emit(TicketBought{
        raffle_id: object::id(raffle),
        player: ctx.sender(),
        player_index: raffle.players
    });

    transfer::public_transfer(ticket, ctx.sender());
}

entry fun choose_winner<T>(raffle: &mut Raffle<T>, clock: &Clock, r: &Random, ctx: &mut TxContext){
    assert!(clock::timestamp_ms(clock) >= raffle.end_time, ERaffleNotEnded);
    assert!(raffle.winner == option::none(), EWinnerAlreadyFound);
    assert!(raffle.players > 0, ENoPlayers);

    let mut generator = random::new_generator(r, ctx);
    let winner = random::generate_u64_in_range(&mut generator, 1, raffle.players);
    raffle.winner = option::some(winner);

    event::emit(WinnerChosen {
        raffle_id: object::id(raffle),
        winner_index: winner
    });
}

#[allow(lint(self_transfer))]
public fun winner_redeem_price<T>(ticket: Ticket, raffle: Raffle<T>, ctx: &mut TxContext){
    assert!(raffle.winner.contains(&ticket.player_index), ENotWinner);

    let Ticket { id, raffle_id: _, player_index: _ } = ticket;
    object::delete(id);

    let raffle_id = object::id(&raffle);

    let Raffle<T> {
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

    event::emit(PrizeRedeemed{
        raffle_id,
        winner: ctx.sender(),
        amount: coin::value(&prize)
    });

    transfer::public_transfer(prize, ctx.sender());
}

public fun delete_raffle<T>(admin_cap: &AdminCap, raffle: Raffle<T>){
    assert!(admin_cap.raffle_id == object::id(&raffle), EAdminCapRaffleMismatch);
    assert!(raffle.players == 0, ERaffleNotEmpty);
    assert!(raffle.balance.value() == 0, EBalanceNotZero);
    let Raffle<T>{
        id,
        ticket_price: _,
        start_time: _,
        end_time: _,
        creator: _,
        balance,
        players: _,
        winner: _,
    } = raffle;
    id.delete();
    balance::destroy_zero(balance);
}

// Getter Functions
public fun ticket_price<T>(raffle: &mut Raffle<T>) :u64{
    raffle.ticket_price
}

public fun start_time<T>(raffle: &mut Raffle<T>) :u64{
    raffle.start_time
}

public fun end_time<T>(raffle: &mut Raffle<T>) :u64{
    raffle.end_time
}

public fun creator<T>(raffle: &mut Raffle<T>) :address{
    raffle.creator
}

public fun balance<T>(raffle: &mut Raffle<T>) :&Balance<T>{
    &raffle.balance
}

public fun balance_value<T: store>(raffle: &Raffle<T>): u64{
    raffle.balance.value()
}

public fun players<T>(raffle: &mut Raffle<T>) :u64{
    raffle.players
}

public fun winner<T>(raffle: &mut Raffle<T>): &Option<u64>{
    &raffle.winner
}

public fun raffle_id(ticket: &mut Ticket) :ID{
    ticket.raffle_id
}

public fun player_index(ticket: &mut Ticket) :u64{
    ticket.player_index
}


