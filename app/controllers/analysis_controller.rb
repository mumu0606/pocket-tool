#coding:utf-8
class AnalysisController < ApplicationController
  autocomplete :pokemon, :name
  layout "mylayout"

  PARTY_SIZE = 6
  NO_MOVE_ID = 606 #技なしのid
  NO_ITEM_ID = 0   #持ち物なしのid

  def index
    @result_hash = {}
    if params[:party_member]
      input_party_ids = params[:party_member]
      get_kp_hash(translate_name_to_id(input_party_ids))
    end
  end


private
  #kp_hashを計算し，それを用いて各ポケモンのアイテム・技予測を行う
  #ke_hash: 各pokemon_dataのidをキーにしてそのパーティに対してどれだけポケモンがかぶっているかの値をvalueとする
  #member_id_arr: パーティーメンバーのidを格納した配列
  def get_kp_hash(member_id_arr)
    member_id_arr.each_with_index do |member_id,i|
      #一緒に手持ちに入れられているポケモンのid配列を取得
      partner_id_arr = except_at(member_id_arr, i)
      pokemon_datum = PokemonData.where(pokemon_id:member_id)

      #ポケモンデータに格納された各行の情報に対して一緒に手持ちに入れられているポケモンがどれだけかぶっているかを計算する
      kp_hash = {}
      pokemon_datum.each do |row|
        kp = 0
        kp += 1 if partner_id_arr.include?(row["partner1"])
        kp += 1 if partner_id_arr.include?(row["partner2"])
        kp += 1 if partner_id_arr.include?(row["partner3"])
        kp += 1 if partner_id_arr.include?(row["partner4"])
        kp += 1 if partner_id_arr.include?(row["partner5"])
        kp_hash[row.id] = kp
      end

      input_poke_name = Pokemon.find(input_poke_id)["name"]
      @result_hash[input_poke_name] = predict_item_moves_on_kp(partner_kp_hash)
    end
  end

  #配列から特定のindex番目の要素を除いた配列を返す
  def except_at(arr, index)
    unless index == 0
      excepted_arr = arr.slice(0..index-1) + arr.slice(index+1..-1)
    else
      excepted_arr = arr.slice(1..-1)
    end
    return excepted_arr
  end

  #how_to_calc_prob::
  #アイテム及び技の予測値の計算方法（予測値大の方が出やすい）
  #アイテム::KP合計
  #技::KP合計 + 最有力のアイテムと技の共起度
  def predict_item_moves_on_kp(partner_kp_hash)
    result_hash = {"item" => nil, "move1" => nil, "move2" => nil, "move3" => nil, "move4" => nil}
    item_prob_hash = {}
    move_prob_hash = {}
    partner_kp_hash.each do |pokemon_info_id,kp|
      item_id = PokemonInfo.find(pokemon_info_id)["item"]
      move_id_arr = []
      move_id_arr.push(PokemonInfo.find(pokemon_info_id)["move1"])
      move_id_arr.push(PokemonInfo.find(pokemon_info_id)["move2"])
      move_id_arr.push(PokemonInfo.find(pokemon_info_id)["move3"])
      move_id_arr.push(PokemonInfo.find(pokemon_info_id)["move4"])

      item_prob_hash[item_id] ||= kp
      item_prob_hash[item_id] += kp
      move_id_arr.each do |move_id|
        move_prob_hash[move_id] ||= kp
        move_prob_hash[move_id] += kp
      end
    end

    #予想される持ち物
    sorted_item_prob_arr = item_prob_hash.sort {|(k1, v1), (k2, v2)| v2 <=> v1 }
    prob_item_id = sorted_item_prob_arr.first.present? ? sorted_item_prob_arr.first.first : NO_ITEM_ID

    #持ち物と技の共起度で技の予測値を更新
    move_prob_hash.each_key do |move_id|
      move_item = MoveItem.where("move_id = ? and item_id = ?", move_id, prob_item_id)
      cooccur = move_item.present? ? move_item.first["cooccur"] : 0
      move_prob_hash[move_id] += cooccur
    end

    #技候補がない場合は"-"と表示するのでNO_MOVE_IDを代入
    sorted_move_prob_arr = move_prob_hash.sort {|(k1, v1), (k2, v2)| v2 <=> v1 }
    prob_move1_id = sorted_move_prob_arr[0].present? ? sorted_move_prob_arr[0].first : NO_MOVE_ID
    prob_move2_id = sorted_move_prob_arr[1].present? ? sorted_move_prob_arr[1].first : NO_MOVE_ID
    prob_move3_id = sorted_move_prob_arr[2].present? ? sorted_move_prob_arr[2].first : NO_MOVE_ID
    prob_move4_id = sorted_move_prob_arr[3].present? ? sorted_move_prob_arr[3].first : NO_MOVE_ID

    result_hash["item"] = Item.find(prob_item_id)["name"]
    result_hash["move1"] = Move.find(prob_move1_id)["name"]
    result_hash["move2"] = Move.find(prob_move2_id)["name"]
    result_hash["move3"] = Move.find(prob_move3_id)["name"]
    result_hash["move4"] = Move.find(prob_move4_id)["name"]

    return result_hash
  end
end