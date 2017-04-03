module Inventory
  class ShrinkOps
    class << self

=begin

Enter how much to may the grower for what is being shrunk, enter the amount to shrink. Shrink info does not display to the grower. They are paid for all qty
Likely do not need to add/change existing products of a PO, but need to create visibility via transaction listing for market.

=end

      def shrink_product(user, order, params)

        t_id = ConsignmentTransaction.find(params[:transaction_id])
        ct = ConsignmentTransaction.create(
            parent_id: params[:transaction_id],
            market_id: order.market.id,
            transaction_type: 'SHRINK',
            order_id: order.id,
            product_id: t_id.product_id,
            quantity: params[:shrink_qty],
            net_price: params[:shrink_cost]
        )
        ct.save
        Audit.create!(user_id:user.id, action:"create", auditable_type: "ConsignmentTransaction", auditable_id: order.id, audited_changes: {'transaction_type' => 'Shrink', 'quantity' => params[:shrink_qty], 'net_price' => params[:shrink_cost]})

      end

      def unshrink_product(user, params)
        t_id = ConsignmentTransaction.find(params[:transaction_id])
        t_id.soft_delete
        Audit.create!(user_id:user.id, action:"create", auditable_type: "ConsignmentTransaction", auditable_id: order.id, audited_changes: {'transaction_type' => 'Undo Shrink'})

      end

      def can_shrink_product?
      end

    end
  end
end