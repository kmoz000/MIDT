use anchor_lang::prelude::*;
use anchor_lang::solana_program::pubkey::Pubkey;
use borsh::{BorshDeserialize, BorshSerialize};

declare_id!("4CZvwi8K9GsRguDxfY6aFBPkDt3tmtHHtLPGcRLzsWTi");

#[program]
pub mod secure_medical_records {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, role: u8) -> Result<()> {
        let account = &mut ctx.accounts.my_account;
        account.role = role;
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }

    pub fn assign_badge(ctx: Context<AssignBadge>, role: u8) -> Result<()> {
        let user = &mut ctx.accounts.user;
        user.role = role;
        Ok(())
    }

    pub fn request_access(ctx: Context<RequestAccess>, request_id: u64) -> Result<()> {
        let access_request = &mut ctx.accounts.access_request;
        access_request.request_id = request_id;
        access_request.approved = false;
        Ok(())
    }

    pub fn approve_access(ctx: Context<ApproveAccess>, request_id: u64) -> Result<()> {
        let access_request = &mut ctx.accounts.access_request;
        if access_request.request_id == request_id {
            access_request.approved = true;
        }
        Ok(())
    }

    pub fn store_medical_record(
        ctx: Context<StoreMedicalRecord>,
        ipfs_cid: String,
        signature: Vec<u8>,
    ) -> Result<()> {
        let user = &mut ctx.accounts.user;
        user.medical_record_cid = ipfs_cid;
        user.signature = signature;
        Ok(())
    }

    pub fn grant_write_access(ctx: Context<GrantWriteAccess>, grantee: Pubkey) -> Result<()> {
        let user = &mut ctx.accounts.user;
        user.write_access_list.push(grantee);
        Ok(())
    }

    pub fn update_medical_record(
        ctx: Context<UpdateMedicalRecord>,
        new_ipfs_cid: String,
    ) -> Result<()> {
        let user = &mut ctx.accounts.user;
        let signer = &ctx.accounts.signer;

        // Check if the signer has write access
        if !user.write_access_list.contains(signer.key) {
            return Err(ErrorCode::Unauthorized.into());
        }

        user.medical_record_cid = new_ipfs_cid;
        Ok(())
    }

    pub fn get_signature(ctx: Context<GetSignature>) -> Result<Vec<u8>> {
        let user = &ctx.accounts.user;
        let requester = &ctx.accounts.requester;

        // Check if the requester is authorized
        if !user.write_access_list.contains(requester.key) {
            return Err(ErrorCode::Unauthorized.into());
        }

        Ok(user.signature.clone())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = user, space = 8 + 1 + 32 + 32 + 4 + 32 * 10)]
    // 8 bytes for discriminator, 1 byte for role, 32 bytes for IPFS CID, 32 bytes for encryption key, 4 bytes for ACL length, 32 bytes for each ACL entry (max 10 entries)
    pub my_account: Account<'info, UserAccount>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct AssignBadge<'info> {
    #[account(mut)]
    pub user: Account<'info, UserAccount>,
}

#[derive(Accounts)]
pub struct RequestAccess<'info> {
    #[account(mut)]
    pub access_request: Account<'info, AccessRequest>,
}

#[derive(Accounts)]
pub struct ApproveAccess<'info> {
    #[account(mut)]
    pub access_request: Account<'info, AccessRequest>,
}

#[derive(Accounts)]
pub struct StoreMedicalRecord<'info> {
    #[account(mut)]
    pub user: Account<'info, UserAccount>,
}

#[derive(Accounts)]
pub struct GrantWriteAccess<'info> {
    #[account(mut)]
    pub user: Account<'info, UserAccount>,
}

#[derive(Accounts)]
pub struct UpdateMedicalRecord<'info> {
    #[account(mut)]
    pub user: Account<'info, UserAccount>,
    pub signer: Signer<'info>,
}

#[derive(Accounts)]
pub struct GetSignature<'info> {
    #[account(mut)]
    pub user: Account<'info, UserAccount>,
    pub requester: Signer<'info>,
}

#[account]
pub struct UserAccount {
    pub role: u8,
    pub medical_record_cid: String,
    pub signature: Vec<u8>,
    pub write_access_list: Vec<Pubkey>,
}

#[account]
pub struct AccessRequest {
    pub request_id: u64,
    pub approved: bool,
}

#[error_code]
pub enum ErrorCode {
    #[msg("Unauthorized")]
    Unauthorized,
}
