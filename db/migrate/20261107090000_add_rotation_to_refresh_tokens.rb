# Safe for rolling deploys: old code inserts rows without the new columns, so the NOT NULL ones keep DB defaults.
class AddRotationToRefreshTokens < ActiveRecord::Migration[8.1]
  def up
    add_column :refresh_tokens, :family_id, :string
    add_column :refresh_tokens, :absolute_expires_at, :datetime
    add_column :refresh_tokens, :rotated_at, :datetime
    add_column :refresh_tokens, :parent_id, :bigint

    execute <<~SQL
      UPDATE refresh_tokens
      SET family_id = gen_random_uuid()::text,
          absolute_expires_at = created_at + interval '30 days'
    SQL

    change_column_default :refresh_tokens, :family_id, from: nil, to: -> { "gen_random_uuid()::text" }
    change_column_default :refresh_tokens, :absolute_expires_at, from: nil, to: -> { "now() + interval '30 days'" }
    change_column_null :refresh_tokens, :family_id, false
    change_column_null :refresh_tokens, :absolute_expires_at, false

    add_index :refresh_tokens, :family_id
    add_index :refresh_tokens, :parent_id
  end

  def down
    remove_index :refresh_tokens, :parent_id
    remove_index :refresh_tokens, :family_id
    remove_column :refresh_tokens, :parent_id
    remove_column :refresh_tokens, :rotated_at
    remove_column :refresh_tokens, :absolute_expires_at
    remove_column :refresh_tokens, :family_id
  end
end
