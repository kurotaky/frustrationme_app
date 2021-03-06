# coding: utf-8
class User < ActiveRecord::Base
  attr_accessor :mode, :password, :password_confirmation

  has_attached_file :icon_name,
    storage: :s3,
    s3_credentials: "#{Rails.root}/config/s3.yml",
    styles: {thumb: '200x200#'},
    path: "#{Rails.env}/:id/icon_names/:style.:extension",
    default_url: '/assets/users/icon.gif'

  validates_attachment :icon_name,
    presence: true,
    content_type: { content_type: ['image/jpeg', 'image/jpg', 'image/png'] },
    size: { :in => 0..2.megabytes },
    if: "icon_name?"

  has_many :categories
  has_many :fumans
  has_many :comments

  accepts_nested_attributes_for :categories
  accepts_nested_attributes_for :fumans
  accepts_nested_attributes_for :comments

  validates :username,
    presence: true,
    length:   {minimum: 3, maximum: 16},
    format:   {with: /\A^[0-9a-zA-Z\-_]+\z/},
    uniqueness: true

  validates :password,
    presence: {unless: :social?},
    length: {minimum: 4, maximum: 16, if: :password},
    format: {with: /\A[0-9a-zA-Z\-_]+\z/, if: :password},
    confirmation: {if: :password}

  validates :email,
    presence: {unless: :social?},
    format: {with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, if: :email}

  validates :sex,
    inclusion: {in: [1,2], if: :sex}

  before_create :password_hash, unless: :social?
  before_update :password_hash, if: :password

  def self.new_auth_token
    SecureRandom.hex(8)
  end

  # crypt md5
  def password_hash
    self.crypted_password = Digest::MD5.hexdigest(self.password)
  end

  def social?
    @mode == :social
  end

  def self.from_omniauth(auth)
    find_by_provider_and_uid(auth["provider"], auth["uid"]) || create_with_omniauth(auth)
  end

  def self.create_with_omniauth(auth)

    icon_name = nil
    if auth['info']['image'].present?
      icon_name = self.process_uri(auth['info']['image'].gsub(/_normal/, ''))
    end

    params = {
      mode:      :social,
      provider:  auth['provider'],
      uid:       auth['uid'],
      username:  auth['info']['nickname'],
      icon_name: icon_name
    }
    user = User.new(params)

    return false if User.find_by_username(auth['info']['nickname'])

    user.save!

    user
  end

  def self.process_uri(uri)
    open(uri, allow_redirections: :safe) do |r|
      r.base_uri.to_s
    end
  end

  # 指定されたIDから自分が持っているアイテムを抽出
  def checked_items(ids)
    items = Item.joins(:fuman).where('user_id = ?', self.id).where('product_id in (?)', ids)
    list = {}
    items.map{|item| list[item.id] = item.product_id}

    list
  end

  # 登録アイテム一覧
  def items_with_fuman(params, per=10)
    Item.includes(:fuman)
    .joins(:fuman)
    .where('user_id = ?', self.id)
    .fuman_status(params[:status])
    .fuman_category(params[:category_id])
    .order('fumans.created_at desc')
    .page(params[:page]).per(per)
  end

  # フォローしているユーザのアイテム一覧
  def items_with_fuman_for_friends(params, per=10)
    Item.includes(:fuman => :friendship)
    .joins(:fuman => :friendship)
    .where('friendships.user_id = ?', self.id)
    .order('fumans.created_at desc')
    .page(params[:page]).per(per)
  end


  # フォローしているユーザを取得する
  def following(following_id)
    Friendship.where('user_id = ?',      self.id)
              .where('following_id = ?', following_id)
              .first
  end

  # count
  def count_followings
    Friendship.where('user_id = ?', self.id).count
  end

  def count_followers
    Friendship.where('following_id = ?', self.id).count
  end

  # フォローされている人一覧
  def followers(page=1, limit=10)
    Friendship.select('friendships.*, users.username, users.icon_name, users.icon_name_file_name')
      .joins("inner join users on friendships.user_id = users.id")
      .where("following_id = ?", self.id)
      .order("friendships.created_at desc")
      .page(page)
      .per(limit)
  end

  # フォローしている人
  def followings(page=1, limit=10)
    Friendship.select('friendships.*, users.username, users.icon_name, users.icon_name_file_name')
    .joins("inner join users on friendships.following_id = users.id")
    .where("user_id = ?", self.id)
    .order("friendships.created_at desc")
    .page(page)
    .per(limit)
  end

  def unfollow(id)
    Friendship.delete_all(['user_id = ? and following_id = ?', self.id, id])
  end

  def following_ids(ids)
    return [] if ids.blank?
    Friendship.where('user_id = ?', self.id).where("following_id in (?)", ids).map{|f| f.following_id}
  end

  def delete_fuman(fuman_id)
    fuman = Fuman.find_by_id_and_user_id(fuman_id, self.id)
    fuman.destroy

    Comment.delete_all(['user_id = ? and item_id = ?', self.id, fuman.item_id])

    fuman
  end
end
