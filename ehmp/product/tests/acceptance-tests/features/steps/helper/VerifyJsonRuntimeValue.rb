class VerifyJsonRuntimeValue
  # EMPTY function: Ignore testing the attribute 
  # CONTAINS function: Testing that part of the value is exist in the runtime results
  # IS_SET function: Checking that the attribut is exist in one set record - this must be used after some other real data.
  # IS_NOT_SET function: Checking that the attribute is not exist
  # ALL_SET function: Checking that the attribut is exist for all records.   
  
  def verify_json_runtime_vlaue(jsonObject, table)
    @json_object = jsonObject
    @not_exist_or_match_field = []
    @not_exist_or_match_values = []
    @not_exist_or_match_expected = []
    @runtime_json_value_all_records = []
    @match_list_array = jsonObject
    table.rows.each do |field_name, value|
      temp_match_list_array = create_temp_match_list_array
      # p field_name
      # p temp_match_list_array.size
      if !(value.empty?) && (value.upcase.start_with? 'ALL_SET')
        find_array_for_all_exist_records(@json_object, field_name, value)
      else
        array_match_list = find_array_that_has_match_field_name_and_value(temp_match_list_array, field_name, value)
      end
      
    end
    red_flag_field_not_exist_or_match
    # p @runtime_json_value_all_records
  end

  def create_temp_match_list_array
    if @match_list_array.size == 0
      temp_match_list_array = @old_temp_match_list_array
    else
      @old_temp_match_list_array = @match_list_array
      temp_match_list_array = @match_list_array
      @match_list_array = []
    end

    return temp_match_list_array
  end

  def find_array_for_all_exist_records(json_object, field_name, expected_value)
    # @temp_not_exist_field_list = []
    # @temp_not_exist_value_list = []
    # @temp_not_exist_expected_value = []
    # match_list_array = []
    all_run_time_value = []
    json_object.each do |sub_json_array|
      json_runtime = FindJsonValueForField.new
      runtime_json_value = json_runtime.find_value_from_json_for_field(sub_json_array, field_name)
      # p "this runtime value for #{field_name} that has ecpected value of #{expected_value}: #{runtime_json_value}"
      all_run_time_value << runtime_json_value
    end
  
    all_runtime_value_match = []
    all_run_time_value.each do |value|
      # p value
      runtime_value_match = false
      if value.class == Array
        runtime_value_match = true  unless value.all? { |x| x.nil? }
      else
        runtime_value_match = true unless value.nil?
      end
      all_runtime_value_match << runtime_value_match
    end
    # p all_runtime_value_match
    if all_runtime_value_match.include? false
      @not_exist_or_match_field << field_name
      @not_exist_or_match_expected << expected_value
      @not_exist_or_match_values << all_run_time_value
    end
      
  end
  
  def find_array_that_has_match_field_name_and_value(temp_match_list_array, field_name, expected_value)
    @temp_not_exist_field_list = []
    @temp_not_exist_value_list = []
    @temp_not_exist_expected_value = []
    match_list_array = []
    temp_match_list_array.each do |sub_json_array|
      # old function
      # runtime_json_value = look_for_value_of_json_array_with_field_table_name(sub_json_array, field_name)
      # json_runtime = FindJsonValueForField.new
      json_runtime = FindRunTimeJsonValue.new
      
      runtime_json_value = json_runtime.find_value_for_key(sub_json_array, field_name)
      # old_runtime_json_value = json_runtime.find_value_from_json_for_field(sub_json_array, field_name)
      # @runtime_json_value_all_records << runtime_json_value
      # p "this runtime value for #{field_name} that has ecpected value of #{expected_value}: #{runtime_json_value}"
      runtime_value_match = check_runtime_value_match(runtime_json_value, expected_value)
      match_list_array = create_match_list_array(runtime_value_match, sub_json_array)
      temp_not_match_list_array = create_temp_not_match_list_array(runtime_value_match, runtime_json_value, field_name, expected_value)
    end
    create_not_match_list_array(temp_match_list_array.size)
  end

  def look_for_value_of_json_array_with_field_table_name(json_array, field_name)
    # look_for_field_name_exist(json_array,field_name)
    runtime_json_value = look_for_json_value(json_array, field_name)
    return runtime_json_value
  end

  def look_for_json_value(json_array, field_name)
    fields = field_name.split('.')
    fields.each do |field|
    # p field
    # p json_array.class
      if json_array.class == Array
        # p 'array'
        json_array = find_sub_json_value_for_array(json_array, field)
      elsif json_array.class == NilClass
        json_array_value = nil
      else
        json_array = json_array[field]
      end

    end
    json_array_value = json_array
    return json_array_value
  end

  def find_sub_json_value_for_array(json_array, field)
    # p "sub array"
    sub_json_array_value = []
    json_array.each do |sub_array|
    # p sub_array.class
      if sub_array.class == Array
        sub_json_array_value = sub_is_array(sub_array, field, sub_json_array_value)
      else
        sub_json_array_value = sub_not_array(sub_array, field, sub_json_array_value)
      end
    end
    if sub_json_array_value.size == 1
      sub_json_array_value = sub_json_array_value[0]
    end
    # p sub_json_array_value
    # p "sub array"
    return sub_json_array_value
  end
  
  def sub_is_array(sub_array, field, sub_json_array_value)
    sub_array.each do |sub_sub_array|
      unless  sub_sub_array[field].nil?
        sub_json_array_value << sub_sub_array[field]
      end
    end
    return sub_json_array_value
  end
  
  def sub_not_array(sub_array, field, sub_json_array_value)
    unless sub_array.nil?
      if sub_array.class == Array && sub_array.size == 1
        sub_array = sub_array[0]
      end
      unless  sub_array[field].nil?
        sub_json_array_value << sub_array[field]
      end
    end
    return sub_json_array_value
  end

  def check_runtime_value_match(runtime_json_value, expected_value)
    if expected_value.empty?
      runtime_value_match = false
    elsif expected_value.upcase.start_with? 'EMPTY'
      runtime_value_match = true
    elsif expected_value.upcase.start_with? 'CONTAINS'
      runtime_value_match = check_runtime_value_with_expected_contains(runtime_json_value, expected_value)
    elsif (expected_value.upcase.start_with? 'DOES_NOT_EXIST') || (expected_value.upcase.start_with? "IS_NOT_SET")
      runtime_value_match = check_runtime_value_with_expected_doesnotexist(runtime_json_value, expected_value)
    elsif expected_value.upcase.start_with? 'IS_SET'
      runtime_value_match = check_runtime_value_with_expected_is_set(runtime_json_value)
    else
      runtime_value_match = check_runtime_value_with_expected(runtime_json_value, expected_value)
    end
    return runtime_value_match
  end

  def check_runtime_value_with_expected_contains(runtime_json_value, expected_value)
    runtime_value_match = false
    expected_value = expected_value[9..-1]
    
    if (runtime_json_value.class != NilClass) && (runtime_json_value.class == Array)
      runtime_json_value.each do |value|
        if value.include? expected_value
          runtime_value_match = true
          break
        end
      end
    elsif (runtime_json_value.class != NilClass) && (runtime_json_value.include? expected_value)
      runtime_value_match = true
    end
    
    return runtime_value_match
  end
  
  def check_runtime_value_with_expected_doesnotexist(runtime_json_value, expected_value)
    runtime_value_match = true
    # expected_value = expected_value[15..-1]
    expected_value = nil

    if (runtime_json_value.class != NilClass) && (runtime_json_value.class == Array)
      runtime_json_value.each do |value|
        if value != expected_value
          runtime_value_match = false
          break
        end
      end
    elsif runtime_json_value.class != NilClass
      runtime_value_match = false
    end
    return runtime_value_match
  end

  def check_runtime_value_with_expected_is_set(values)
    runtime_value_match = false
    if values.class == Array
      unless (values.all? { |x| x.nil? }) || (values.all? { |x| x.empty? })
        runtime_value_match = true
      end
    else
      unless values == nil
        runtime_value_match = true
      end
    end
    # p "value is #{values} and match result is #{runtime_value_match}"
    return runtime_value_match
  end

  def check_runtime_value_with_expected(runtime_json_value, expected_value)
    runtime_value_match = false
     # ------------------
    unless runtime_json_value == nil
      if (runtime_json_value.class == Array) && (runtime_json_value.include? expected_value)
         #            p 'Array--'
        runtime_value_match = true
      elsif (runtime_json_value.class == Array) && (runtime_json_value.include? expected_value.to_f)
        #            p 'Array flaot--'
        value_nil_match = true
        runtime_value_match = true
      else
        runtime_value_match = true if runtime_json_value.to_s == expected_value
      end
    end 
    # --------------------

    # if runtime_json_value.class == NilClass
      # #            p "nil"
      # #      ignor
    # elsif (runtime_json_value.class == String) && (runtime_json_value == expected_value)
      # #            p 'string'
      # runtime_value_match = true
    # elsif ((runtime_json_value.class == Float) || (runtime_json_value.class == Fixnum)) && (runtime_json_value == expected_value.to_f)
      # #            p 'float'
      # runtime_value_match = true
    # elsif (runtime_json_value.class == TrueClass) && (runtime_json_value.to_s == expected_value)
      # #            p 'TrueClass'
      # runtime_value_match = true
    # elsif (runtime_json_value.class == Array) && (runtime_json_value.include? expected_value)
      # #            p 'Array--'
      # runtime_value_match = true
    # elsif (runtime_json_value.class == Array) && (runtime_json_value.include? expected_value.to_f)
      # #            p 'Array flaot--'
      # value_nil_match = true
      # runtime_value_match = true
    # elsif (expected_value != nil) && ((expected_value.upcase == "TRUE") || (expected_value.upcase == "FALSE"))
                   # # p 'trueclass--'
      # if expected_value.upcase == "TRUE"
        # expected_value = true
      # else
        # expected_value = false
      # end
# 
      # if (runtime_json_value.class == FalseClass || runtime_json_value.class == TrueClass) && (runtime_json_value == expected_value)
        # runtime_value_match = true
      # elsif (runtime_json_value.class == Array) && (runtime_json_value.include? expected_value)
        # #        p 'trueclass'
        # runtime_value_match = true
      # end
    # else
      # #            p 'not match'
      # #      ignor
    # end
    
    return runtime_value_match
  end

  def create_match_list_array(runtime_value_match, sub_json_array)
    if runtime_value_match == true
      @match_list_array << sub_json_array
    end
  end

  def create_temp_not_match_list_array(runtime_value_match, runtime_json_array_value, field_name, expected_value)
    if runtime_value_match == false
      unless @temp_not_exist_field_list.include? field_name
        @temp_not_exist_field_list << field_name
        @temp_not_exist_expected_value << expected_value

      end
      @temp_not_exist_value_list << runtime_json_array_value
    end
  end

  def create_not_match_list_array(temp_match_list_array_size)
    if @temp_not_exist_value_list.size ==  temp_match_list_array_size
      @not_exist_or_match_field <<  @temp_not_exist_field_list[0]
      @not_exist_or_match_values <<  @temp_not_exist_value_list
      @not_exist_or_match_expected <<  @temp_not_exist_expected_value[0]
    end
  end

  def red_flag_field_not_exist_or_match
    # p 'red flag'
    # p @not_exist_or_match_field
    # p @not_exist_or_match_values
    # p @not_exist_or_match_expected
    @error_message = []
    unless @not_exist_or_match_field.empty?
      index = 0
      @not_exist_or_match_field.each do |not_exist_or_match_field|
        create_not_exist_or_match_error(not_exist_or_match_field, @not_exist_or_match_expected[index], @not_exist_or_match_values[index])
        index = index + 1
      end
      error_exception_message @error_message
    end
  end

  def create_not_exist_or_match_error(field, expected_value, runtime_values)
    values_has_nil = check_values_has_nil runtime_values

    if expected_value.start_with? 'AllNotMatch'
      expected_value = expected_value.sub('AllNotMatch', '')
      @error_message << "There are some other than '#{expected_value}' values for field '#{field}' .\n Returned Json values:"+"\n"+"#{runtime_values}"
    elsif (expected_value.upcase.start_with? 'DOES_NOT_EXIST') || (expected_value.upcase.start_with? 'IS_NOT_SET')
      @error_message << "There is match found in field '#{field}' for value of '#{expected_value}' .\n Returned Json values:"+"\n"+"#{runtime_values}"
    elsif expected_value.upcase.start_with? 'ALL_SET'
      @error_message << "There is some recorde(s) that does not have any value for field '#{field}' by using '#{expected_value}' .\n Returned Json values:"+"\n"+"#{runtime_values}"
    elsif values_has_nil == 'all nil'
      @error_message << "Unexpected field '#{field}'."
    elsif values_has_nil == 'has nil'
      @error_message << "This field has null value '#{field}'.\n Returned Json values:"+"\n"+"#{runtime_values}"
    else
      @error_message << "There is no match found in field '#{field}' for value of '#{expected_value}' .\n Returned Json values:"+"\n"+"#{runtime_values}"
    end
  end

  def check_values_has_nil(values)
    string_count_index=0

    values.map do |value|
      string_value =  "'" + values.to_s + "'"

      if (string_value.include? 'nil') || (string_value.include? '[]') || (string_value.include? "''")
        string_count_index = string_count_index + 1
      end
    end
    if string_count_index == values.size
      values_has_nil = 'all nil'
    elsif string_count_index > 0
      values_has_nil = 'has nil'
    else
      values_has_nil = 'no nil'
    end
    return values_has_nil
  end

  def error_exception_message(error_message)
    text_error_message = "\n"
    for i in 0..error_message.size-1
      text_error_message = text_error_message +(i+1).to_s+" - "+ error_message[i]+"\n\n"
    end
    initialize
    fail text_error_message
  end
  
  def verify_json_runtime_just_contain_expected_value(jsonObject, table, expected_value)
    @not_exist_or_match_field = []
    @not_exist_or_match_values = []
    @not_exist_or_match_expected = []
    @match_list_array = jsonObject
    table.rows.each do |field_name|
      # p field_name[0]
      array_match_list = find_array_that_has_match_field_name_and_expected_value(jsonObject, field_name[0], expected_value)
    end
    red_flag_field_not_exist_or_match
  end
  
  def find_array_that_has_match_field_name_and_expected_value(jsonObject, field_name, expected_value)
    @temp_not_exist_field_list = []
    @temp_not_exist_value_list = []
    @temp_not_exist_expected_value = []
    jsonObject.each do |sub_json_array|
      runtime_json_value = look_for_value_of_json_array_with_field_table_name(sub_json_array, field_name)
      runtime_value_match = check_runtime_value_match(runtime_json_value, expected_value)
      # match_list_array = create_match_list_array(runtime_value_match, sub_json_array)
      temp_not_match_list_array = create_temp_not_match_list_array(runtime_value_match, runtime_json_value, field_name, expected_value)
    end
    create_not_match_list_array_just_contain
  end
  
  def create_not_match_list_array_just_contain
    unless @temp_not_exist_field_list.empty?
      @not_exist_or_match_field <<  @temp_not_exist_field_list[0]
      @not_exist_or_match_values <<  @temp_not_exist_value_list
      @not_exist_or_match_expected <<  "AllNotMatch"+@temp_not_exist_expected_value[0]
    end
  end
end

class FindJsonValueForField
  def find_value_from_json_for_field(runtime_json_object, fields_name)
    value = ''
    fields = fields_name.split('.')
    fields.each do |field_name|
      value = find_json_value(runtime_json_object, field_name)
      runtime_json_object = value
    end
    if value.class == Array && value.size == 1
      value = value[0]
    end
    return value
  end

  def find_json_value(runtime_json_object, field_name)
    json_class = runtime_json_object.class
    if json_class == NilClass
      value = nil
    elsif json_class == Array
      value = find_json_value_for_array(runtime_json_object, field_name) - [nil]
    else
      value = find_json_value_for_hash(runtime_json_object, field_name)
    end
    return value
  end

  def find_json_value_for_hash(runtime_json_object, field_name)
    sub_value = nil
    unless runtime_json_object[field_name].nil?
      sub_value = runtime_json_object[field_name]
    end
    return sub_value
  end
  
  def find_json_value_for_array(runtime_json_object, field_name)    
    value = []
    @temp_hash_runtime_json_object = []
    temp_array_runtime_json_object = runtime_json_object

    until temp_array_runtime_json_object.empty?
      temp_runtime = break_arrray_to_hash(temp_array_runtime_json_object)
      temp_array_runtime_json_object = temp_runtime[0]
    end
    
    @temp_hash_runtime_json_object.each do |sub_runtime_json_object|
      value << find_sub_value(sub_runtime_json_object, field_name)
    end
    # p '*'*100
    # p value
    return value
  end
  
  def break_arrray_to_hash(runtime_json_object)
    temp_array_runtime_json_object = []
    runtime_json_object.each do |sub_runtime_json_object|
      sub_class = sub_runtime_json_object.class
      if sub_class == Array
        temp_array_runtime_json_object = temp_array_runtime_json_object + sub_runtime_json_object
      else
        @temp_hash_runtime_json_object << sub_runtime_json_object
      end
    end
    return temp_array_runtime_json_object, @temp_hash_runtime_json_object
  end
  
  def find_sub_value(sub_runtime_json_object, field_name)
    sub_class = sub_runtime_json_object.class
    if sub_class == NilClass
      value = nil
    else
      value = find_json_value_for_hash(sub_runtime_json_object, field_name)
    end
    return value
  end
end

class FindRunTimeJsonValue
  def initialized12
    # p "initialize"
    @result = []
  end

  def find_all_values_for(jsob_object, key)
    # p @result
    # p key
    if jsob_object.is_a? Hash
      @result << jsob_object[key]
    else
      i = 0
      jsob_object.each do |value|
        @result = find_all_values_for(value, key) #if value.is_a? Hash
      end
    end
    return @result
  end

  def find_value_for_key(json_object, field_list)
    fields = field_list.split"."
    fields.each do |field|
      initialized12
      tst1 = find_all_values_for(json_object, field)
      json_object = tst1
      json_object = tst1[0] if tst1.size == 1
      break if json_object.nil?
    end
    return json_object
  end
end  
