#[test_only]
module raffle::raffle_tests;

use sui::test_scenario as ts;
use sui::test_utils::assert_eq;
use sui::clock::{Clock, create_for_testing, share_for_testing, increment_for_testing};
use sui::coin::{Self, Coin};
use sui::random;           
use sui::random::Random;    
use sui::sui::SUI;         

use raffle::raffle::{
    Raffle,
    create_raffle, buy_ticket, choose_winner, 
    EIncorrectTiCketPrice, ERaffleEnded, ERaffleNotEnded
};

const CREATOR: address = @0xA;
const PLAYER1: address = @0xB;


#[test]
fun test_create_raffle_success() {
    let mut scenario = ts::begin(CREATOR); {
        let clock = create_for_testing(scenario.ctx());
        share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        let start_time = 0;
        let end_time = 1000;
        create_raffle<SUI>(100, start_time, end_time, scenario.ctx());
    };

    let effects = ts::next_tx(&mut scenario, CREATOR);
    assert_eq(effects.num_user_events(), 1);
    scenario.end();
}

#[test]
fun test_buy_ticket_success() {
    let mut scenario = ts::begin(CREATOR); {
        let clock = create_for_testing(scenario.ctx());
        share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        create_raffle<SUI>(100, 0, 2000, scenario.ctx());
    };

    ts::next_tx(&mut scenario, PLAYER1);
    {
        let mut raffle = ts::take_shared<Raffle<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let coin: Coin<SUI> = coin::mint_for_testing<SUI>(100, scenario.ctx());
        buy_ticket(&mut raffle, coin, &clock, scenario.ctx());
        ts::return_shared(raffle);
        ts::return_shared(clock);
    };

    let effects = ts::next_tx(&mut scenario, PLAYER1);
    assert_eq(effects.num_user_events(), 1); 
    scenario.end();
}

#[test, expected_failure(abort_code = EIncorrectTiCketPrice)]
fun test_buy_ticket_fails_incorrect_price() {
    let mut scenario = ts::begin(CREATOR); {
        let clock = create_for_testing(scenario.ctx());
        share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        create_raffle<SUI>(100, 0, 2000, scenario.ctx());
    };

    ts::next_tx(&mut scenario, PLAYER1);
    {
        let mut raffle = ts::take_shared<Raffle<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let coin: Coin<SUI> = coin::mint_for_testing<SUI>(50, scenario.ctx()); 
        buy_ticket(&mut raffle, coin, &clock, scenario.ctx());
        ts::return_shared(raffle);
        ts::return_shared(clock);
    };

    scenario.end();
}

#[test, expected_failure(abort_code = ERaffleEnded)]
fun test_buy_ticket_fails_after_end_time() {
    let mut scenario = ts::begin(CREATOR); {
        let clock = create_for_testing(scenario.ctx());
        share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        create_raffle<SUI>(100, 0, 1000, scenario.ctx());
    };

    // advance time in a following tx
    ts::next_tx(&mut scenario, CREATOR);
    {
        let mut clock = ts::take_shared<Clock>(&scenario);
        increment_for_testing(&mut clock, 2000);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, PLAYER1);
    {
        let mut raffle = ts::take_shared<Raffle<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let coin: Coin<SUI> = coin::mint_for_testing<SUI>(100, scenario.ctx());
        buy_ticket(&mut raffle, coin, &clock, scenario.ctx());
        ts::return_shared(raffle);
        ts::return_shared(clock);
    };

    scenario.end();
}

#[test]
fun test_choose_winner_success() {
    let mut scenario = ts::begin(CREATOR); 
    {
        let clock = create_for_testing(scenario.ctx());
        share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(scenario.ctx());
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        create_raffle<SUI>(100, 0, 1000, scenario.ctx());
    };

    ts::next_tx(&mut scenario, PLAYER1);
    {
        let mut raffle = ts::take_shared<Raffle<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let coin: Coin<SUI> = coin::mint_for_testing<SUI>(100, scenario.ctx());
        buy_ticket(&mut raffle, coin, &clock, scenario.ctx());
        ts::return_shared(raffle);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        let mut clock = ts::take_shared<Clock>(&scenario);
        increment_for_testing(&mut clock, 2000);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        let mut raffle = ts::take_shared<Raffle<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let random = ts::take_shared<Random>(&scenario);
        choose_winner(&mut raffle, &clock, &random, scenario.ctx());
        ts::return_shared(raffle);
        ts::return_shared(clock);
        ts::return_shared(random);
    };

    let effects = ts::next_tx(&mut scenario, CREATOR);
    assert_eq(effects.num_user_events(), 1); // WinnerChosen event
    scenario.end();
}

#[test, expected_failure(abort_code = ERaffleNotEnded)]
fun test_choose_winner_fails_before_end_time() {
    let mut scenario = ts::begin(CREATOR); 
    {
        let clock = create_for_testing(scenario.ctx());
        share_for_testing(clock);
    };

    ts::next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(scenario.ctx());
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        create_raffle<SUI>(100, 0, 1000, scenario.ctx());
    };

    ts::next_tx(&mut scenario, PLAYER1);
    {
        let mut raffle = ts::take_shared<Raffle<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let coin: Coin<SUI> = coin::mint_for_testing<SUI>(100, scenario.ctx());
        buy_ticket(&mut raffle, coin, &clock, scenario.ctx());
        ts::return_shared(raffle);
        ts::return_shared(clock);
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        let mut raffle = ts::take_shared<Raffle<SUI>>(&scenario);
        let clock = ts::take_shared<Clock>(&scenario);
        let random = ts::take_shared<Random>(&scenario);
        choose_winner(&mut raffle, &clock, &random, scenario.ctx()); // expected to abort ERaffleNotEnded
        ts::return_shared(raffle);
        ts::return_shared(clock);
        ts::return_shared(random);
    };

    scenario.end();
}

