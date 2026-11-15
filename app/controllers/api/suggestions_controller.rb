module Api
  # The autocompletions of the interface: the users of the access list and
  # the tags of an inventory.
  class SuggestionsController < BaseController
    # The number of answers of an autocompletion.
    LIMIT = 10

    # The users that may be added to the access list.
    def users
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      users = User.active
                  .where("LOWER(users.name) LIKE :q OR LOWER(users.email) LIKE :q", q: "%#{query.downcase}%")
                  .order(Arel.sql("LOWER(users.name) ASC"))
                  .limit(LIMIT)

      render json: users.map { |user| user_json(user) }
    end

    # The tags that start with the given text.
    def tags
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      render json: Tag.starting_with(query, limit: LIMIT).map { |tag| { id: tag.id, name: tag.name } }
    end

    private

    # The public data of a user.
    def user_json(user)
      { id: user.id, name: user.display_name, email: user.email, avatar_url: user.avatar_url }
    end
  end
end
