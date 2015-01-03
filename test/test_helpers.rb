module TestHelpers
  
  def get_valid_eson
    load_test_inputs('valid')
  end

  private

  def load_test_inputs(name)
    file = File.join('../../test/eson_inputs', "#{name}.eson")
    File.open(File.expand_path(file, __FILE__)).read 
  end
end
