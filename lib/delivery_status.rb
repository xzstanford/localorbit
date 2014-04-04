module DeliveryStatus
  def delivery_status
    statuses = items.pluck(:delivery_status).uniq.map(&:downcase)

    # TODO: Currently, canceled will only return if all items are canceled, this logic needs to be confirmed
    if statuses.size == 1
      statuses.first
    elsif statuses_within(statuses, ["pending", "delivered", "contested"])
      "contested, partially delivered"
    elsif statuses.include?("contested")
      "contested"
    elsif statuses_within(statuses, ["delivered", "pending"])
      "partially delivered"
    end
  end

  private

  def statuses_within(statuses, query)
    (query & statuses) == query
  end
end