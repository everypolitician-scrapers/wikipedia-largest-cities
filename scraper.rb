#!/usr/bin/env ruby

require 'scraperwiki'
require 'scraped'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'
# require 'open-uri'

class CityRow < Scraped::HTML
  field :city_name do
    city_link.text
  end

  field :city_item do
    city_link.attribute('wikidata').value
  end

  field :country_name do
    city_link.text
  end

  field :country_wikidata do
    country_link.attribute('wikidata').value
  end

  field :population do
    Integer(tds[2].text.sub(/^\s*([0-9,]+).*/m, '\1').tr(',', ''))
  end

  private

  def country_link
    tds[0].css('a')
  end

  def city_link
    @city_link ||= noko.css('th').css('a')
  end

  def tds
    @tds ||= noko.css('td')
  end

  def population_td
    tds[2]
  end
end

class ListPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    noko.xpath('//table[contains(@class, "wikitable")]/tr').drop(2).map do |row|
      fragment row => CityRow
    end
  end
end

url = 'https://en.wikipedia.org/wiki/List_of_largest_cities'
data = ListPage.new(response: Scraped::Request.new(url: url).response).members.map(&:to_h)

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite([:city_item], data)
