module FastXmlArrayExt
  def to_xml options = {}
    # puts 'FastXml: using FastXml replacement for Array#to_xml' 
    # puts options.inspect

    raise "Not all elements respond to to_xml" unless all? { 
      |e| e.respond_to? :to_xml 
    }

    if options[:strip]
      options[:skip_instruct] = true
      options[:skip_types] = true
      options[:skip_nil] = true
      options[:indent] = false
    end

    options = options.dup

    options[:root]     ||= first.class.to_s.underscore.pluralize.dasherize
    options[:children] ||= options[:root].singularize
    options[:indent]     = 2 if options[:indent] == nil

    root     = options.delete(:root).to_s
    children = options.delete(:children)

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
      e_xml = e.to_xml(opts.merge({ 
        :skip_instruct => true, :fast_xml_caller => true }))
      if e_xml.class == LibXML::XML::Node
        xml << e_xml
      elsif e_xml.class == String
        # TODO: seems like a lot of overhead here.
        puts "WARNING: slow stuff going on here (find me in fast_xml/core_ext.rb)"
        other_doc = LibXML::XML::Parser.string(e_xml).parse 
        xml << doc.import(other_doc.root)
      else
        raise "Cannot handle xml data of type #{e_xml.class.name}"
      end
    }
    
    options[:fast_xml_caller] ? xml : xml.to_s(:indent => options[:indent])
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

    if options[:strip]
      options[:skip_instruct] = true
      options[:skip_types] = true
      options[:skip_nil] = true
      options[:indent] = false
    end

    root = self.class.name.underscore.downcase.dasherize
    xml = LibXML::XML::Node.new(root)
    
    if options[:only]
      attributes_for_xml = {}
      options[:only].each { |only_field|
        if attribute_value = attributes[only_field.to_s]
          attributes_for_xml[only_field.to_s] = attribute_value 
        end
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
      xml << att_node = LibXML::XML::Node.new(a.dasherize)
      if v
        type_name   = XML_TYPE_NAMES[v.class.name.to_s]
        type_name ||= v.class.name.downcase
        att_node << (XML_FORMATTING[type_name] ? 
          XML_FORMATTING[type_name].call(v) : v)
        att_node.attributes['type'] = type_name unless options[:skip_types]
      elsif not options[:skip_nil]
        att_node.attributes['nil'] = 'true'
      end
    }

    options[:fast_xml_caller] ? xml : xml.to_s(:indent => options[:indent])
  end
end


::Array.class_eval do
  alias to_xml_original to_xml
  include FastXmlArrayExt
end

::ActiveRecord::Base.class_eval do
  alias to_xml_original to_xml
  include FastXmlActiveRecordBaseExt
end
