module Jekyll
  module Converters
    class Markdown
      class KramdownParser
        private def filter(root, under_p = false)
          if root.type == :text and under_p
            root.value.gsub!(/(?<=[^\p{ASCII}])\n *(?=[^\p{ASCII}])/, "")
          end
          root.children.each{|c| filter(c, root.type == :p)}
        end

        def convert(content)
          doc = Kramdown::Document.new(content, @config)
          filter(doc.root)
          doc.to_html
        end
      end
    end
  end
end
