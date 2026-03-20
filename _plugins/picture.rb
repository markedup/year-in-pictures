require './_lib/db_control'

class PictureMarkup < Liquid::Tag
  def initialize(tag_name, text, tokens)
    super
    params = text.split
    @month = params[0]
  end

  def render(context)
    # Get the year from the page frontmatter and picture details from the db
    year = context.registers[:page]['year']
    pics = DbControl.get_month_pictures(@month, year)

    "#{head_html(year)}#{middle_html(pics, year)}#{foot_html}"
  end

  def head_html(year)
    <<-HEAD
  <section class="month" id="#{@month}">
    <h2><a href="##{@month}">#{@month.capitalize} #{year}</a></h2>
    <ul class="polaroids pure-g">
    HEAD
  end

  def middle_html(pics, year)
    pics.map do |pic|
      <<-ITERATOR
        <li class="pure-u-1-2 pure-u-sm-1-2 pure-u-lg-1-3">
          <a title="#{pic['caption']}" href="/photos/#{year}/#{pic['filename']}">
            <img loading="lazy" alt="#{pic['alt']}" src="/images/#{year}/thumbnails/#{pic['image_filename']}">
          </a>
        </li>
      ITERATOR
    end.join
  end

  def foot_html
    <<-FOOT
    </ul>
  </section>
    FOOT
  end

  Liquid::Template.register_tag 'picture', self
end
