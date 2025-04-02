
// #[allow(duplicate_alias)]
// module 0x0::DynamicNFT {
//     use sui::object::{UID, Self};
//     use sui::tx_context::{TxContext, sender};
//     use sui::transfer;
//     // use sui::object;

//     /// Define the NFT struct
//     public struct NFT has key, store {
//         id: UID,
//         owner: address,
//         level: u8,  // Dynamic level that can be upgraded
//         name: vector<u8>,  // Name of the NFT
//     }

//     /// Function to mint a new NFT
//     public entry fun mint_nft(name: vector<u8>, ctx: &mut TxContext) {
//         let nft = NFT {
//             id: object::new(ctx),  // Corrected UID creation
//             owner: sender(ctx),
//             level: 1,  // Default starting level
//             name,
//         };
//         transfer::public_transfer(nft, sender(ctx));
//     }

//     /// Function to upgrade an NFT (level up)
//     public entry fun upgrade_nft(nft: &mut NFT) {
//         nft.level = nft.level + 1;
//     }

//     /// Function to get NFT metadata (returns current details)
//     public fun get_nft_metadata(nft: &NFT): (address, u8, vector<u8>) {
//         (nft.owner, nft.level, nft.name)
//     }

//     /// Function to transfer NFT to another user
//     public entry fun transfer_nft(nft: NFT, recipient: address) {
//         transfer::public_transfer(nft, recipient);
//     }
// }

#[allow(duplicate_alias,unused_use)]
// #[allow(unused_use)]
module 0x0::DynamicNFT {
    use sui::object::{UID};
    use sui::tx_context::TxContext;
    use sui::transfer;
    use std::string::{Self, String};
    use sui::event;

    // ========== STRUCT DECLARATIONS ==========
    public struct NFT has key, store {
        id: UID,
        owner: address,
        level: u8,
        name: String,
        soulbound: bool
    }

    public struct NFTCreated has copy, drop {
        nft_id: ID,
        owner: address,
        name: String
    }

    public struct NFTUpgraded has copy, drop {
        nft_id: ID,
        old_level: u8,
        new_level: u8
    }

    // ========== CONSTANTS ==========
    const ESOULBOUND: u64 = 0;
    const ENOT_OWNER: u64 = 1;

    // ========== ENTRY FUNCTIONS ==========
    public entry fun mint_nft(name: String, ctx: &mut TxContext) {
    // Create copies of values needed after transfer
        let owner = tx_context::sender(ctx);
        let name_copy = copy name;
        
        let nft = NFT {
            id: object::new(ctx),
            owner: copy owner,
            level: 1,
            name,  // Original name is moved here
            soulbound: false
        };
        
        let nft_id = object::uid_to_inner(&nft.id);
        transfer::public_transfer(nft, owner);
        
        // Use the copies we made earlier
        event::emit(NFTCreated {
            nft_id,
            owner,
            name: name_copy
        });
    }
    public entry fun upgrade_nft(
        nft: &mut NFT,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(!nft.soulbound, ESOULBOUND);
        
        let old_level = nft.level;
        nft.level = nft.level + 1;
        
        event::emit(NFTUpgraded {
            nft_id: object::uid_to_inner(&nft.id),
            old_level,
            new_level: nft.level
        });
    }

    public entry fun soulbind_nft(
        nft: &mut NFT,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        nft.soulbound = true;
    }

    public entry fun transfer_nft(
        nft: NFT,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == nft.owner, ENOT_OWNER);
        assert!(!nft.soulbound, ESOULBOUND);
        transfer::public_transfer(nft, recipient);
    }
}