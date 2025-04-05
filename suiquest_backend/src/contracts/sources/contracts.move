
#[allow(duplicate_alias,unused_use)]
module 0x0::DynamicNFT {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::string::{Self, String};
    use sui::event;
    use sui::vec_map::{Self, VecMap};
    use std::vector; // Corrected to use std::vector

    // ========== STRUCT DECLARATIONS ==========
    public struct NFT has key, store {
        id: UID,
        owner: address,
        level: u8,
        name: String,
        soulbound: bool,
        locked_for_bridge: bool,
        metadata: VecMap<String, String>,
    }
    // Getter functions for private fields
    public fun get_owner(nft: &NFT): address {
        nft.owner
    }

    public fun get_id(nft: &NFT): &UID {
        &nft.id
    }

    public struct NFTCreated has copy, drop {
        nft_id: ID,
        owner: address,
        name: String,
    }

    public struct NFTUpgraded has copy, drop {
        nft_id: ID,
        old_level: u8,
        new_level: u8,
    }

    public struct NFTBurned has copy, drop {
        nft_id: ID,
        owner: address,
    }

    public struct MetadataUpdated has copy, drop {
        nft_id: ID,
        key: String,
        value: String,
    }

    public struct NFTsFused has copy, drop {
        new_nft_id: ID,
        burned_nft_ids: vector<ID>,
        owner: address,
    }

    public struct NFTLockedForBridge has copy, drop {
        nft_id: ID,
        owner: address,
    }

    public struct NFTUnlockedFromBridge has copy, drop {
        nft_id: ID,
        owner: address,
    }

    // ========== CONSTANTS ==========
    const ESOULBOUND: u64 = 0;
    const ENOT_OWNER: u64 = 1;
    const ELOCKED_FOR_BRIDGE: u64 = 2;
    const ENOT_LOCKED: u64 = 3;
    const ELEVEL_TOO_HIGH: u64 = 4;

    // ========== ENTRY FUNCTIONS ==========

    public entry fun mint_nft(name: String, ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);
        let name_copy = copy name;
        
        let nft = NFT {
            id: object::new(ctx),
            owner,
            level: 1,
            name,
            soulbound: false,
            locked_for_bridge: false,
            metadata: vec_map::empty(),
        };
        
        let nft_id = object::uid_to_inner(&nft.id);
        transfer::public_transfer(nft, owner);
        
        event::emit(NFTCreated {
            nft_id,
            owner,
            name: name_copy,
        });
    }

    public entry fun upgrade_nft(nft: &mut NFT, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(!nft.soulbound, ESOULBOUND);
        assert!(!nft.locked_for_bridge, ELOCKED_FOR_BRIDGE);
        assert!(nft.level < 255, ELEVEL_TOO_HIGH);
        
        let old_level = nft.level;
        nft.level = nft.level + 1;
        
        event::emit(NFTUpgraded {
            nft_id: object::uid_to_inner(&nft.id),
            old_level,
            new_level: nft.level,
        });
    }

    public entry fun soulbind_nft(nft: &mut NFT, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(!nft.locked_for_bridge, ELOCKED_FOR_BRIDGE);
        nft.soulbound = true;
    }

    public entry fun transfer_nft(nft: NFT, recipient: address, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(!nft.soulbound, ESOULBOUND);
        assert!(!nft.locked_for_bridge, ELOCKED_FOR_BRIDGE);
        transfer::public_transfer(nft, recipient);
    }

    public entry fun burn_nft(nft: NFT, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(!nft.locked_for_bridge, ELOCKED_FOR_BRIDGE);
        
        let nft_id = object::uid_to_inner(&nft.id);
        let NFT { id, owner, level: _, name: _, soulbound: _, locked_for_bridge: _, metadata: _ } = nft;
        object::delete(id);
        
        event::emit(NFTBurned {
            nft_id,
            owner,
        });
    }
    public fun mint(owner: address, name: String, ctx: &mut TxContext): NFT {
        let nft = NFT {
            id: object::new(ctx),
            owner,
            level: 1,
            name,
            soulbound: false,
            locked_for_bridge: false,
            metadata: vec_map::empty(),
        };
        
        event::emit(NFTCreated {
            nft_id: object::uid_to_inner(&nft.id),
            owner,
            name: copy name,
        });

        nft
    }
    // public fun get_rarity(nft: &NFT): u64 {
    //     match nft.level {
    //         1 => 1,   // Common
    //         2 => 5,   // Rare
    //         3 => 10,  // Epic
    //         4 => 20,  // Legendary
    //         _ => 2,   // Default multiplier for others
    //     }
    // }

    public entry fun set_nft_metadata(nft: &mut NFT, key: String, value: String, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(!nft.locked_for_bridge, ELOCKED_FOR_BRIDGE);
        
        vec_map::insert(&mut nft.metadata, key, value);
        
        event::emit(MetadataUpdated {
            nft_id: object::uid_to_inner(&nft.id),
            key,
            value,
        });
    }
    // Inside 0x0::DynamicNFT module
    
    public fun get_id_inner(nft: &NFT): ID {
        object::uid_to_inner(&nft.id)
    }
    // Also add getters for any other fields needed externally (like owner)
    // public fun get_owner(nft: &NFT): address {
    //     nft.owner
    // }
    public fun get_nft_metadata(nft: &NFT): (u8, String, bool, bool, &VecMap<String, String>) {
        (nft.level, nft.name, nft.soulbound, nft.locked_for_bridge, &nft.metadata)
    }

    public entry fun fuse_nfts(nft1: NFT, nft2: NFT, new_name: String, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(nft1.owner == sender && nft2.owner == sender, ENOT_OWNER);
        assert!(!nft1.soulbound && !nft2.soulbound, ESOULBOUND);
        assert!(!nft1.locked_for_bridge && !nft2.locked_for_bridge, ELOCKED_FOR_BRIDGE);
        
        let mut new_level = (nft1.level + nft2.level) / 2 + 1;
        if (new_level > 255) { new_level = 255 };
        
        let new_nft = NFT {
            id: object::new(ctx),
            owner: sender,
            level: new_level,
            name: new_name,
            soulbound: false,
            locked_for_bridge: false,
            metadata: vec_map::empty(),
        };
        
        let new_nft_id = object::uid_to_inner(&new_nft.id);
        let burned_nft_ids = vector[object::uid_to_inner(&nft1.id), object::uid_to_inner(&nft2.id)];
        
        let NFT { id: id1, owner: _, level: _, name: _, soulbound: _, locked_for_bridge: _, metadata: _ } = nft1;
        let NFT { id: id2, owner: _, level: _, name: _, soulbound: _, locked_for_bridge: _, metadata: _ } = nft2;
        object::delete(id1);
        object::delete(id2);
        
        transfer::public_transfer(new_nft, sender);
        
        event::emit(NFTsFused {
            new_nft_id,
            burned_nft_ids,
            owner: sender,
        });
    }

    public entry fun lock_nft_for_bridge(nft: &mut NFT, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(!nft.soulbound, ESOULBOUND);
        assert!(!nft.locked_for_bridge, ELOCKED_FOR_BRIDGE);
        
        nft.locked_for_bridge = true;
        
        event::emit(NFTLockedForBridge {
            nft_id: object::uid_to_inner(&nft.id),
            owner: nft.owner,
        });
    }
    // public fun get_rarity(nft: &NFT): u64 {
    //     let level = nft.level;
    //     if (level == 1) {
    //         1
    //     } else if (level == 2) {
    //         5
    //     } else if (level == 3) {
    //         10
    //     } else if (level == 4) {
    //         20
    //     } else {
    //         2
    //     }
    // }
    public fun mint_for_reinvest(name: String, level: u8, ctx: &mut TxContext): NFT {
        let owner = tx_context::sender(ctx);

        let nft = NFT {
            id: object::new(ctx),
            owner,
            level,
            name,
            soulbound: false,
            locked_for_bridge: false,
            metadata: vec_map::empty(),
        };

        event::emit(NFTCreated {
            nft_id: object::uid_to_inner(&nft.id),
            owner,
            name,
        });

        nft
    }


    public entry fun unlock_nft_from_bridge(nft: &mut NFT, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(nft.locked_for_bridge, ENOT_LOCKED);
        
        nft.locked_for_bridge = false;
        
        event::emit(NFTUnlockedFromBridge {
            nft_id: object::uid_to_inner(&nft.id),
            owner: nft.owner,
        });
    }

    public entry fun batch_upgrade_nfts(mut nfts: vector<NFT>, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let len = vector::length(&nfts);
        let mut i = 0;
        
        while (i < len) {
            let mut nft = vector::remove(&mut nfts, i);
            assert!(nft.owner == sender, ENOT_OWNER);
            assert!(!nft.soulbound, ESOULBOUND);
            assert!(!nft.locked_for_bridge, ELOCKED_FOR_BRIDGE);
            assert!(nft.level < 255, ELEVEL_TOO_HIGH);
            
            let old_level = nft.level;
            nft.level = nft.level + 1;
            
            event::emit(NFTUpgraded {
                nft_id: object::uid_to_inner(&nft.id),
                old_level,
                new_level: nft.level,
            });
            
            transfer::public_transfer(nft, sender);
            i = i + 1;
        };
        
        vector::destroy_empty(nfts);
    }
}