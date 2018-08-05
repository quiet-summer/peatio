# encoding: UTF-8
# frozen_string_literal: true

module BlockchainService
  class Ethereum < Base
    # Rough number of blocks per hour for Ethereum is 250.
    def process_blockchain(blocks_limit: 250, force: false)
      latest_block = client.latest_block_number

      # Don't start process if we didn't receive new blocks.
      if blockchain.height + blockchain.min_confirmations >= latest_block && !force
        Rails.logger.info { "Skip synchronization. No new blocks detected height: #{blockchain.height}, latest_block: #{latest_block}" }
        return
      end

      from_block   = blockchain.height || 0
      to_block     = [latest_block, from_block + blocks_limit].min

      (from_block..to_block).each do |block_id|
        Rails.logger.info { "Started processing #{blockchain.key} block number #{block_id}." }

        block_json = client.get_block(block_id)

        next if block_json.blank? || block_json['transactions'].blank?

        deposits    = build_deposits(block_json)
        withdrawals = build_withdrawals(block_json)

        deposits.map { |d| d[:txid] }.join(',').tap do |txids|
          Rails.logger.info { "Deposit trancations in block #{block_id}: #{txids}" }
        end

        withdrawals.map { |w| w[:txid] }.join(',').tap do |txids|
          Rails.logger.info { "Withdraw trancations in block #{block_id}: #{txids}" }
        end
        update_or_create_deposits!(deposits)
        update_withdrawals!(withdrawals)

        # Mark block as processed if both deposits and withdrawals were confirmed.
        blockchain.update(height: block_id) if latest_block - block_id >= blockchain.min_confirmations

        Rails.logger.info { "Finished processing #{blockchain.key} block number #{block_id}." }
      rescue => e
        report_exception(e)
      end
    end

    private

    def build_deposits(block_json)
      block_json
        .fetch('transactions')
        .each_with_object([]) do |block_txn, deposits|

          if block_txn.fetch('input').hex <= 0
            txn = block_txn
            next if client.invalid_eth_transaction?(txn)
          else
            txn = client.get_txn_receipt(block_txn.fetch('hash'))
	    next if txn.nil? || client.invalid_erc20_transaction?(txn)
          end

          payment_addresses_where(address: client.to_address(txn)) do |payment_address|

            deposit_txs = client.build_transaction(txn, block_json, payment_address.currency) # block_txn required for ETH transaction
            deposit_txs.fetch(:entries).each_with_index do |entry, i|
              deposits << { txid:           deposit_txs[:id],
                            address:        entry[:address],
                            amount:         entry[:amount],
                            member:         payment_address.account.member,
                            currency:       payment_address.currency,
                            txout:          i,
                            block_number:   deposit_txs[:block_number] }
            end
          end
        end
    end

    def build_withdrawals(block_json)
      block_json
        .fetch('transactions')
        .each_with_object([]) do |block_txn, withdrawals|

          Withdraws::Coin
            .where(currency: currencies)
            .where(txid: client.normalize_txid(block_txn.fetch('hash')))
            .each do |withdraw|

            if block_txn.fetch('input').hex <= 0
              txn = block_txn
              next if client.invalid_eth_transaction?(txn)
            else
              txn = client.get_txn_receipt(block_txn.fetch('hash'))
	      next if txn.nil? || client.invalid_erc20_transaction?(txn)
            end

            withdraw_txs = client.build_transaction(txn, block_json, withdraw.currency)  # block_txn required for ETH transaction
            withdraw_txs.fetch(:entries).each do |entry|
            withdrawals << { txid:           withdraw_txs[:id],
                             rid:            entry[:address],
                             amount:         entry[:amount],
                             block_number:   withdraw_txs[:block_number] }
            end
          end
        end
    end
  end
end

