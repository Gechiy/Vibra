# Music Track NFT Smart Contract

A Clarity smart contract for the Stacks blockchain that enables creators to mint, release, and trade music tracks as NFTs with built-in royalty distribution.

## Features

- **NFT Minting**: Create unique music track NFTs with customizable royalty splits
- **Track Release System**: List tracks for sale with configurable pricing
- **Royalty Distribution**: Automatic royalty payments to original producers on secondary sales
- **Studio Management**: Administrative controls for maintenance and management
- **Price Modification**: Update release prices with cooldown periods
- **Transfer System**: Direct peer-to-peer track transfers

## Contract Overview

### Core Components

- **NFT Definition**: Each track is represented as a unique NFT with a track ID
- **Release System**: Tracks can be listed for public purchase
- **Royalty System**: Original producers earn royalties on all future sales
- **Administrative Controls**: Studio owner and manager roles for contract governance

## Constants

| Constant | Value | Description |
|----------|--------|-------------|
| `TRACK_MIN_PRICE` | 1 µSTX | Minimum release price |
| `TRACK_MAX_PRICE` | 1,000,000,000 µSTX | Maximum release price |
| `MAX_ROYALTY_SPLIT` | 30% | Maximum royalty percentage |
| `MAX_TRACK_NUMBER` | 1,000,000 | Maximum track ID |
| `RELEASE_MODIFICATION_COOLDOWN` | 24 hours | Cooldown between price changes |

## Functions

### Administrative Functions

#### `appoint-studio-manager`
```clarity
(appoint-studio-manager (new-manager principal))
```
Allows the studio owner to appoint a new studio manager.

**Parameters:**
- `new-manager`: Principal address of the new manager

**Access:** Studio owner only

#### `toggle-studio-maintenance`
```clarity
(toggle-studio-maintenance)
```
Toggles the studio's maintenance mode on/off.

**Access:** Studio manager only

### Core Functions

#### `studio-mint`
```clarity
(studio-mint (track-num uint) (royalty-split uint))
```
Mints a new music track NFT.

**Parameters:**
- `track-num`: Unique identifier for the track (0 to 1,000,000)
- `royalty-split`: Percentage of future sales paid to original producer (0-30%)

**Returns:** `(ok true)` on success

#### `studio-release`
```clarity
(studio-release (track-num uint) (release-price uint))
```
Lists a track for public purchase.

**Parameters:**
- `track-num`: Track ID to release
- `release-price`: Price in microSTX (1 to 1,000,000,000)

**Access:** Track owner only

#### `modify-release-price`
```clarity
(modify-release-price (track-num uint) (updated-price uint))
```
Updates the release price of a listed track.

**Parameters:**
- `track-num`: Track ID to modify
- `updated-price`: New price in microSTX

**Access:** Track owner only
**Cooldown:** 24 hours between modifications

#### `withdraw-from-release`
```clarity
(withdraw-from-release (track-num uint))
```
Removes a track from public sale.

**Parameters:**
- `track-num`: Track ID to withdraw

**Access:** Track owner only

#### `studio-purchase`
```clarity
(studio-purchase (track-num uint))
```
Purchases a released track, handling automatic royalty distribution.

**Parameters:**
- `track-num`: Track ID to purchase

**Payment Flow:**
1. Royalty payment sent to original producer
2. Remaining amount sent to current seller
3. NFT transferred to buyer
4. Track removed from release listings

#### `transfer-track`
```clarity
(transfer-track (track-num uint) (recipient principal))
```
Directly transfers track ownership without payment.

**Parameters:**
- `track-num`: Track ID to transfer
- `recipient`: Principal address of the recipient

**Access:** Track owner only

### Read-Only Functions

#### `is-track-available`
```clarity
(is-track-available (track-num uint))
```
Checks if a track is currently available for purchase.

#### `get-track-release-info`
```clarity
(get-track-release-info (track-num uint))
```
Returns release information for a track.

**Returns:**
```clarity
{
  producer: principal,
  release-price: uint,
  released-at: uint
}
```

#### `get-producer-royalty-info`
```clarity
(get-producer-royalty-info (track-num uint))
```
Returns royalty information for a track.

**Returns:**
```clarity
{
  original-producer: principal,
  royalty-split: uint
}
```

#### `calculate-royalty-payment`
```clarity
(calculate-royalty-payment (price uint) (split uint))
```
Calculates the royalty amount for a given price and split percentage.

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u101 | `ERR_TRACK_NOT_AVAILABLE` | Track is not listed for sale |
| u102 | `ERR_INSUFFICIENT_STX` | Buyer has insufficient STX balance |
| u103 | `ERR_PURCHASE_FAILED` | Purchase transaction failed |
| u104 | `ERR_INVALID_ROYALTY_SPLIT` | Royalty split exceeds maximum (30%) |
| u105 | `ERR_UNAUTHORIZED_ACCESS` | Caller lacks required permissions |
| u106 | `ERR_CANNOT_PURCHASE_OWN_TRACK` | Cannot purchase your own track |
| u107 | `ERR_INVALID_TRACK_PRICE` | Price outside valid range |
| u108 | `ERR_MODIFICATION_COOLDOWN` | Must wait before modifying price again |
| u109 | `ERR_STUDIO_MAINTENANCE` | Studio is in maintenance mode |
| u110 | `ERR_TRACK_ALREADY_RELEASED` | Track is already listed for sale |
| u111 | `ERR_INVALID_TRACK_NUMBER` | Track number outside valid range |
| u112 | `ERR_INVALID_MANAGER` | Invalid manager appointment |

## Usage Examples

### Minting a Track
```clarity
;; Mint track #123 with 10% royalty split
(contract-call? .music-nft studio-mint u123 u10)
```

### Releasing a Track
```clarity
;; Release track #123 for 1000 microSTX
(contract-call? .music-nft studio-release u123 u1000)
```

### Purchasing a Track
```clarity
;; Purchase track #123 (automatically handles payment distribution)
(contract-call? .music-nft studio-purchase u123)
```

### Modifying Price
```clarity
;; Update track #123 price to 2000 microSTX (after cooldown period)
(contract-call? .music-nft modify-release-price u123 u2000)
```

## Events

The contract emits the following events for off-chain tracking:

- `track-minted`: When a new track is minted
- `track-released`: When a track is listed for sale
- `track-purchased`: When a track is purchased
- `track-transferred`: When a track is directly transferred
- `release-price-modified`: When a release price is updated
- `track-withdrawn-from-release`: When a track is removed from sale
- `studio-manager-appointed`: When a new studio manager is appointed

## Security Features

- **Access Control**: Role-based permissions for administrative functions
- **Validation**: Comprehensive input validation for all parameters
- **Cooldown Periods**: Prevents rapid price manipulation
- **Maintenance Mode**: Emergency pause functionality
- **Self-Purchase Prevention**: Users cannot purchase their own tracks
- **Balance Verification**: Ensures sufficient funds before transactions

## Deployment

1. Deploy the contract to the Stacks blockchain
2. The deployer becomes the studio owner
3. Appoint a studio manager if desired
4. Users can begin minting and trading tracks


