class BankAccount < ActiveRecord::Base
  include SoftDelete

  attr_accessor :save_for_future

  belongs_to :bankable, polymorphic: true

  validate :account_is_unique_to_bankable

  private

  def account_is_unique_to_bankable
    if bankable.bank_accounts.visible.where(account_type: account_type, last_four: last_four).any?
      errors.add(:bankable, "already exists for this #{bankable_type.downcase}.")
    end
  end
end
