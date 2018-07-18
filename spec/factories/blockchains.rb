# encoding: UTF-8
# frozen_string_literal: true

FactoryBot.define do
  factory :blockchain do
    trait 'eth-rinkeby' do
      key                     'eth-rinkeby'
      name                    'Ethereum Rinkeby'
      client                  'ethereum'
      server                  'http://127.0.0.1:8545'
      height                  2500000
      min_confirmations       6
      explorer_address        'https://etherscan.io/address/#{address}'
      explorer_transaction    'https://etherscan.io/tx/#{txid}'
      status                  'active'
    end

    trait 'eth-mainet' do
      key                     'eth-mainet'
      name                    'Ethereum Mainet'
      client                  'ethereum'
      server                  'http://127.0.0.1:8545'
      height                  2500000
      min_confirmations       4
      explorer_address        'https://etherscan.io/address/#{address}'
      explorer_transaction    'https://etherscan.io/tx/#{txid}'
      status                  'disabled'
    end
  end
end
