require 'vanilla/dynasnip'

class Index < Dynasnip
  def get(*args)
    list = app.soup.all_snips.sort_by { |a| a.updated_at }.reverse.map { |snip|
      "<li>#{link_to snip.name}</li>"
    }
    "<ol>#{list}</ol>"
  end
end
