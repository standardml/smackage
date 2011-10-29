signature HTTP_DOWNLOADER =
sig
  exception HttpException of string
  type url = string
  type filename = string

  val retrieve : url -> filename -> unit
  val retrieveLines : url -> string list
  val retrieveCleanLines : url -> string list
end
