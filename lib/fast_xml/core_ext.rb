module FastXmlArrayExt
  def to_xml options = {}
    # puts 'FastXml: using FastXml replacement for Array#to_xml' 
    # puts options.inspect

    raise "Not all elements respond to to_xml" unless all? { 
      |e| e.respond_to? :to_xml 
    }

    options = options.dup

    options[:root]     ||= all? { |e| 
      e.is_a?(first.class) && first.class.to_s != "Hash" 
    } ? first.class.to_s.underscore.pluralize : "records"

    options[:children] ||= options[:root].singularize
    options[:indent]   ||= 2

    root     = options.delete(:root).to_s
    children = options.delete(:children)

    if !options.has_key?(:dasherize) || options[:dasherize]
      root = root.dasherize
    end
    
    node = LibXML::XML::Node.new(root)
    opts = options.merge({ :root => children })

    unless options.delete(:skip_instruct)
      doc = LibXML::XML::Document.new
      doc.root = node
      xml = doc.root
    else
      xml = node
    end

    xml.attributes['type'] = 'array' unless options[:skip_types]

    each { |e|
      e_xml = e.to_xml(opts.merge({ :skip_instruct => true }))
      if e_xml.class == LibXML::XML::Node
        xml << e_xml        
      elsif e_xml.class == String
        # TODO: seems like a lot of overhead here.
        other_doc = LibXML::XML::Parser.string(e_xml).parse 
        xml << doc.import(other_doc.root)
      else
        raise "Cannot handle xml data of type #{e_xml.class.name}"
      end
    }

    xml
  end
end

module FastXmlHashExt
  def to_xml options = {}
    # puts 'FastXml: using FastXml replacement for Hash#to_xml' 
    # puts options.inspect
    to_xml_original options
  end
end

module FastXmlActiveRecordBaseExt
  XML_TYPE_NAMES = 
    ActiveSupport::CoreExtensions::Hash::Conversions::XML_TYPE_NAMES

  XML_FORMATTING = 
    ActiveSupport::CoreExtensions::Hash::Conversions::XML_FORMATTING

  def to_xml options = {}
    # puts 'FastXml: using FastXml replacement for ActiveRecord::Base#to_xml'
    # puts options.inspect

    root_node = LibXML::XML::Node.new(self.class.name.downcase)
    
    if options[:only]
      attributes_for_xml = {}
      options[:only].each { |only_field|
        attributes_for_xml[only_field.to_s] = attributes[only_field.to_s] if 
          attributes[only_field.to_s]
      }
    else
      attributes_for_xml = attributes
      options[:except].each { |except_field| 
        attributes_for_xml.delete except_field.to_s
      }
    end

    options[:methods].each { |m|
      attributes_for_xml[m.to_s] = self.send(m.to_s)
    } if options[:methods]
    
    attributes_for_xml.each { |a,v| 
      root_node << att_node = LibXML::XML::Node.new(a.dasherize)
      if v
        type_name   = XML_TYPE_NAMES[v.class.name.to_s]
        type_name ||= v.class.name.downcase

        att_node << (XML_FORMATTING[type_name] ? 
          XML_FORMATTING[type_name].call(v) : v)

        att_node.attributes['type'] = type_name
      else
        att_node.attributes['nil'] = 'true'
      end
    }

    root_node
  end
end


::Array.class_eval do
  alias to_xml_original to_xml
  include FastXmlArrayExt
end

::Hash.class_eval do
  alias to_xml_original to_xml
  include FastXmlHashExt
end

::ActiveRecord::Base.class_eval do
  alias to_xml_original to_xml
  include FastXmlActiveRecordBaseExt
end
