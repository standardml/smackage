signature HTTP_DOWNLOADER =
sig
  exception HttpException of string
  type url = string
  type filename = string

  val retrieveTemp : url -> filename
  val retrieve : url -> filename -> unit
  val retrieveText : url -> string
end
