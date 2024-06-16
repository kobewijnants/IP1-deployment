## Use the official .NET SDK as a build image (of kies een eigen versie vb. 7.0)
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /app

# Copy csproj and restore as distinct layers (verander naar eigen mappen, dockerfile moet in root van project zijn!)
ADD UI-MVC ./UI-MVC
ADD BL ./BL 
ADD DAL ./DAL
ADD Domain ./Domain
RUN dotnet restore UI-MVC/UI-MVC.csproj

# Webpack isntall en build
#RUN apt-get update -yq && apt-get upgrade -yq && apt-get install -yq npm nodejs
#WORKDIR /Phygital/MVC/ClientApp
#RUN npm install
#RUN npm run build

# Copy everything else and build
COPY . .
RUN dotnet publish -c Release -o out

# Use the official ASP.NET Core runtime as a runtime image (of kies een eigen versie vb. 7.0)
FROM mcr.microsoft.com/dotnet/aspnet:8.0

WORKDIR /app
COPY --from=build /app/out .

# Expose port 8080 of poort naar keuze
EXPOSE 8080

# Set the ASP.NET Core environment to production 
ENV ASPNETCORE_ENVIRONMENT=Production
ENV PhygitalDbContextConnectionPostgres="Host=34.22.184.227; Database=phygital; Username=postgres; Password=postgres123"

# Start the application verander naar eigen dll van MVC (om dit te vinden doe al dotnet publish -c (releasenaam)
ENTRYPOINT ["dotnet", "DN.UI.Web.dll"]