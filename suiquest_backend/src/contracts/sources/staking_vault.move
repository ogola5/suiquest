#[allow(duplicate_alias,unused_use,unused_const)]

module 0x0::StakingVault {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;
    use 0x0::DynamicNFT::{Self, NFT, get_owner, get_id};
    use std::vector;

    public struct Vault has key {
        id: UID,
        total_staked: u64,
        staked_nfts: vector<NFT>,
        max_capacity: u64,
        reward_rate: u64,
        is_paused: bool,
    }

    public struct StakedNFT has key, store {
        id: UID,
        nft_id: ID,
        owner: address,
        start_epoch: u64,
    }

    public struct NFTStaked has copy, drop {
        nft_id: ID,
        owner: address,
        vault_id: ID,
    }

    public struct RewardsClaimed has copy, drop {
        nft_id: ID,
        owner: address,
        amount: u64,
    }

    public struct NFTUnstaked has copy, drop {
        nft_id: ID,
        owner: address,
        vault_id: ID,
    }

    const ENOT_OWNER: u64 = 1;
    const ESTAKED_NFT_NOT_FOUND: u64 = 2;
    const EALREADY_STAKED: u64 = 3;
    const E_VAULT_FULL: u64 = 4;
    const E_VAULT_PAUSED: u64 = 5;

    public entry fun create_vault(ctx: &mut TxContext) {
        let vault = Vault {
            id: object::new(ctx),
            total_staked: 0,
            staked_nfts: vector::empty(),
            max_capacity: 100,
            reward_rate: 10,
            is_paused: false,
        };
        transfer::transfer(vault, tx_context::sender(ctx));
    }

    public entry fun stake_nft(nft: NFT, vault: &mut Vault, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(DynamicNFT::get_owner(&nft) == sender, ENOT_OWNER);
        assert!(!vault.is_paused, E_VAULT_PAUSED);
        assert!(vault.total_staked < vault.max_capacity, E_VAULT_FULL);

        let nft_id = object::uid_to_inner(DynamicNFT::get_id(&nft));
        let len = vector::length(&vault.staked_nfts);
        let mut i = 0;
        while (i < len) {
            let staked = vector::borrow(&vault.staked_nfts, i);
            assert!(object::uid_to_inner(DynamicNFT::get_id(staked)) != nft_id, EALREADY_STAKED);
            i = i + 1;
        };

        let staked_nft = StakedNFT {
            id: object::new(ctx),
            nft_id,
            owner: sender,
            start_epoch: tx_context::epoch(ctx),
        };

        vault.total_staked = vault.total_staked + 1;
        vector::push_back(&mut vault.staked_nfts, nft);
        transfer::public_transfer(staked_nft, sender);

        event::emit(NFTStaked {
            nft_id,
            owner: sender,
            vault_id: object::uid_to_inner(&vault.id),
        });
    }

    public entry fun claim_rewards(staked_nft: &mut StakedNFT, vault: &Vault, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(staked_nft.owner == sender, ENOT_OWNER);

        let epochs_staked = tx_context::epoch(ctx) - staked_nft.start_epoch;
        let reward_amount = epochs_staked * vault.reward_rate;
        let rewards = coin::mint_for_testing<SUI>(reward_amount, ctx);

        transfer::public_transfer(rewards, sender);
        staked_nft.start_epoch = tx_context::epoch(ctx);

        event::emit(RewardsClaimed {
            nft_id: staked_nft.nft_id,
            owner: sender,
            amount: reward_amount,
        });
    }

    public entry fun unstake_nft(staked_nft: StakedNFT, vault: &mut Vault, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(staked_nft.owner == sender, ENOT_OWNER);

        let mut i = 0;
        let len = vector::length(&vault.staked_nfts);
        let mut found = false;
        while (i < len) {
            let nft = vector::borrow(&vault.staked_nfts, i);
            if (object::uid_to_inner(DynamicNFT::get_id(nft)) == staked_nft.nft_id) {
                let nft = vector::remove(&mut vault.staked_nfts, i);
                transfer::public_transfer(nft, sender);
                found = true;
                break
            };
            i = i + 1;
        };
        assert!(found, ESTAKED_NFT_NOT_FOUND);

        vault.total_staked = vault.total_staked - 1;
        let StakedNFT { id, nft_id, owner, start_epoch: _ } = staked_nft;
        object::delete(id);

        event::emit(NFTUnstaked {
            nft_id,
            owner,
            vault_id: object::uid_to_inner(&vault.id),
        });
    }

    public fun get_staked_nft_info(staked_nft: &StakedNFT, ctx: &TxContext): (ID, address, u64, u64) {
        let epochs_staked = tx_context::epoch(ctx) - staked_nft.start_epoch;
        let reward_amount = epochs_staked * 10;
        (staked_nft.nft_id, staked_nft.owner, staked_nft.start_epoch, reward_amount)
    }
    
    public entry fun set_reward_rate(vault: &mut Vault, new_rate: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == object::uid_to_address(&vault.id), ENOT_OWNER);
        vault.reward_rate = new_rate;
    }
}