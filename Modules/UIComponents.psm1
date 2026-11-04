# Interfejs WPF aplikacji Helpdesk Tools.
# Motyw, kontrolki i układ są wspólne z Domain Ops (AD-ManagerDiamond) i ServerReview:
# ciemny motyw, Segoe UI 13, ikony Segoe Fluent Icons / Segoe MDL2 Assets, karty z zaokrągleniami,
# przełącznik przestrzeni roboczych, lista obiektów z zaznaczaniem, nawigacja modułów, tabela wyników,
# panel szczegółów wiersza, dziennik operacji i pasek stanu.

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

#region Motyw (ciemny, spójny z Domain Ops / ServerReview)
$script:ThemeXaml = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <SolidColorBrush x:Key="BgBrush" Color="#0F1318"/>
  <SolidColorBrush x:Key="PanelBrush" Color="#12171D"/>
  <SolidColorBrush x:Key="PanelBorderBrush" Color="#1E242E"/>
  <SolidColorBrush x:Key="CardBrush" Color="#161B22"/>
  <SolidColorBrush x:Key="CardBorderBrush" Color="#242B36"/>
  <SolidColorBrush x:Key="FieldBrush" Color="#1B212A"/>
  <SolidColorBrush x:Key="FieldBorderBrush" Color="#2A323F"/>
  <SolidColorBrush x:Key="HoverBrush" Color="#1A2029"/>
  <SolidColorBrush x:Key="SelectedBrush" Color="#1A2640"/>
  <SolidColorBrush x:Key="SelectedBorderBrush" Color="#2F4478"/>
  <SolidColorBrush x:Key="TextBrush" Color="#E4E8EF"/>
  <SolidColorBrush x:Key="MutedBrush" Color="#8791A5"/>
  <SolidColorBrush x:Key="FaintBrush" Color="#5E6779"/>
  <SolidColorBrush x:Key="AccentBrush" Color="#3E6FE0"/>
  <SolidColorBrush x:Key="FocusBrush" Color="#4C7DF0"/>
  <SolidColorBrush x:Key="OkBrush" Color="#5EE3AE"/>
  <SolidColorBrush x:Key="WarnBrush" Color="#FFC46B"/>
  <SolidColorBrush x:Key="CritBrush" Color="#FF7A86"/>
  <SolidColorBrush x:Key="InfoBrush" Color="#8CC0FF"/>

  <Style x:Key="Card" TargetType="Border">
    <Setter Property="Background" Value="#161B22"/>
    <Setter Property="BorderBrush" Value="#242B36"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="CornerRadius" Value="10"/>
    <Setter Property="Padding" Value="16,14"/>
  </Style>

  <Style x:Key="Glyph" TargetType="TextBlock">
    <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
    <Setter Property="FontSize" Value="14"/>
    <Setter Property="VerticalAlignment" Value="Center"/>
  </Style>

  <Style x:Key="ScrollThumb" TargetType="Thumb">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Thumb">
          <Border CornerRadius="4" Background="#39414F"/>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ScrollBar">
    <Setter Property="Width" Value="10"/>
    <Setter Property="MinWidth" Value="10"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ScrollBar">
          <Grid Background="Transparent">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}" Margin="2"/></Track.Thumb>
            </Track>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
    <Style.Triggers>
      <Trigger Property="Orientation" Value="Horizontal">
        <Setter Property="Width" Value="Auto"/>
        <Setter Property="MinWidth" Value="0"/>
        <Setter Property="Height" Value="10"/>
        <Setter Property="MinHeight" Value="10"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="ScrollBar">
              <Grid Background="Transparent">
                <Track x:Name="PART_Track" IsDirectionReversed="False">
                  <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}" Margin="2"/></Track.Thumb>
                </Track>
              </Grid>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Trigger>
    </Style.Triggers>
  </Style>

  <Style TargetType="Button">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderBrush" Value="#2A323F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="12,5"/>
    <Setter Property="MinHeight" Value="30"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="HorizontalContentAlignment" Value="Center"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.8"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Background" Value="#3E6FE0"/>
    <Setter Property="BorderBrush" Value="#3E6FE0"/>
    <Setter Property="Foreground" Value="White"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#5582EC"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Foreground" Value="#FF8A95"/>
    <Setter Property="BorderBrush" Value="#4A2A32"/>
    <Setter Property="Background" Value="#21181C"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#3A1F26"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="DangerPrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Background" Value="#D9475A"/>
    <Setter Property="BorderBrush" Value="#D9475A"/>
    <Setter Property="Foreground" Value="White"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#E85C6E"/></Trigger>
    </Style.Triggers>
  </Style>
  <!-- Dodawanie i tworzenie (nowe konto, grupa, członkowie, uprawnienia, licencje) - zielone -->
  <Style x:Key="CreateButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Foreground" Value="#5FD39A"/>
    <Setter Property="BorderBrush" Value="#244A39"/>
    <Setter Property="Background" Value="#15211B"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#1C3327"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="CreatePrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Background" Value="#2C9A5F"/>
    <Setter Property="BorderBrush" Value="#2C9A5F"/>
    <Setter Property="Foreground" Value="White"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#36AE6C"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="GhostButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderBrush" Value="Transparent"/>
    <Setter Property="Foreground" Value="#AEB6C4"/>
    <Setter Property="Padding" Value="8,4"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True">
        <Setter Property="Background" Value="#1E252F"/>
        <Setter Property="Foreground" Value="#E4E8EF"/>
      </Trigger>
    </Style.Triggers>
  </Style>

  <Style TargetType="TextBox">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderBrush" Value="#2A323F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="MinHeight" Value="30"/>
    <Setter Property="CaretBrush" Value="#E4E8EF"/>
    <Setter Property="SelectionBrush" Value="#3E6FE0"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="TextBox">
          <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7">
            <Grid>
              <!-- Padding pola TextBox stosuje sam do tekstu - szablon nie dodaje go drugi raz -->
              <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
              <Border Margin="{TemplateBinding Padding}" IsHitTestVisible="False">
                <TextBlock x:Name="wm" Text="{TemplateBinding Tag}" Foreground="#5E6779" Margin="2,0,0,0"
                           VerticalAlignment="{TemplateBinding VerticalContentAlignment}" Visibility="Collapsed"/>
              </Border>
            </Grid>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="Text" Value=""><Setter TargetName="wm" Property="Visibility" Value="Visible"/></Trigger>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#39445A"/></Trigger>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.45"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="MultiText" TargetType="TextBox" BasedOn="{StaticResource {x:Type TextBox}}">
    <Setter Property="AcceptsReturn" Value="True"/>
    <Setter Property="AcceptsTab" Value="True"/>
    <Setter Property="TextWrapping" Value="NoWrap"/>
    <Setter Property="VerticalContentAlignment" Value="Top"/>
    <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
    <Setter Property="HorizontalScrollBarVisibility" Value="Auto"/>
    <Setter Property="FontFamily" Value="Consolas"/>
    <Setter Property="FontSize" Value="12.5"/>
  </Style>
  <Style x:Key="ReadOnlyText" TargetType="TextBox" BasedOn="{StaticResource MultiText}">
    <Setter Property="IsReadOnly" Value="True"/>
    <Setter Property="AcceptsTab" Value="False"/>
    <Setter Property="TextWrapping" Value="Wrap"/>
    <Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderThickness" Value="0"/>
  </Style>

  <Style x:Key="GridEditText" TargetType="TextBox">
    <Setter Property="Background" Value="#202A3B"/>
    <Setter Property="Foreground" Value="White"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Padding" Value="0"/>
    <Setter Property="Margin" Value="-6,-3"/>
    <Setter Property="MinHeight" Value="0"/>
    <Setter Property="CaretBrush" Value="#E4E8EF"/>
    <Setter Property="SelectionBrush" Value="#3E6FE0"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="TextBox">
          <Border Background="{TemplateBinding Background}" BorderBrush="#4C7DF0" BorderThickness="1" CornerRadius="4" Padding="5,2">
            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="PasswordBox">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderBrush" Value="#2A323F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="MinHeight" Value="30"/>
    <Setter Property="CaretBrush" Value="#E4E8EF"/>
    <Setter Property="SelectionBrush" Value="#3E6FE0"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="PasswordBox">
          <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7">
            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ComboBox">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="MinHeight" Value="30"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ComboBox">
          <Grid>
            <ToggleButton Focusable="False" ClickMode="Press"
                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
              <ToggleButton.Template>
                <ControlTemplate TargetType="ToggleButton">
                  <Border x:Name="bd" Background="#1B212A" BorderBrush="#2A323F" BorderThickness="1" CornerRadius="7">
                    <Path HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,11,0"
                          Data="M 0 0 L 4 4 L 8 0" Stroke="#8791A5" StrokeThickness="1.6"/>
                  </Border>
                  <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate>
              </ToggleButton.Template>
            </ToggleButton>
            <ContentPresenter x:Name="selection" IsHitTestVisible="False" Margin="9,0,28,0" VerticalAlignment="Center"
                              Content="{TemplateBinding SelectionBoxItem}"
                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"/>
            <!-- Lista edytowalna (wybór z listy albo własny tekst): pole tekstowe z wybraną albo wpisaną wartością -->
            <TextBox x:Name="PART_EditableTextBox" Visibility="Collapsed" Margin="3,1,26,1" Padding="5,0" MinHeight="0"
                     VerticalAlignment="Center" VerticalContentAlignment="Center" Background="Transparent" BorderThickness="0"
                     Foreground="{TemplateBinding Foreground}" CaretBrush="#E4E8EF"
                     IsReadOnly="{Binding IsReadOnly, RelativeSource={RelativeSource TemplatedParent}}"/>
            <Popup IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom" AllowsTransparency="True"
                   Focusable="False" PopupAnimation="Fade">
              <Border Background="#1B212A" BorderBrush="#2F3846" BorderThickness="1" CornerRadius="7" Margin="0,3,0,0" Padding="3"
                      MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}" MaxHeight="380">
                <ScrollViewer>
                  <StackPanel IsItemsHost="True"/>
                </ScrollViewer>
              </Border>
            </Popup>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
            <Trigger Property="IsEditable" Value="True">
              <Setter TargetName="PART_EditableTextBox" Property="Visibility" Value="Visible"/>
              <Setter TargetName="selection" Property="Visibility" Value="Collapsed"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ComboBoxItem">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Padding" Value="10,6"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ComboBoxItem">
          <Border x:Name="bd" Background="Transparent" CornerRadius="5" Padding="{TemplateBinding Padding}">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsSelected" Value="True"><Setter TargetName="bd" Property="Background" Value="#22304D"/></Trigger>
            <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="bd" Property="Background" Value="#2C3B5E"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="CheckBox">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="VerticalAlignment" Value="Center"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="CheckBox">
          <Grid Background="Transparent">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <!-- 16 px: całe piksele przy skalowaniu 125/150/175% (17 px bywało przycinane od dołu) -->
            <Border x:Name="box" Width="16" Height="16" Margin="0,1" CornerRadius="4" BorderThickness="1" BorderBrush="#3A4352" Background="#1B212A" VerticalAlignment="Center">
              <Grid>
                <Path x:Name="mark" Data="M 3 7.2 L 5.8 10 L 11 4.2" Stroke="White" StrokeThickness="2" Visibility="Collapsed"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
                <Rectangle x:Name="dash" Width="8" Height="2" Fill="White" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ContentPresenter x:Name="cp" Grid.Column="1" Margin="8,0,0,0" VerticalAlignment="Center"/>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="Content" Value="{x:Null}"><Setter TargetName="cp" Property="Margin" Value="0"/></Trigger>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="box" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="box" Property="Background" Value="#3E6FE0"/>
              <Setter TargetName="box" Property="BorderBrush" Value="#3E6FE0"/>
              <Setter TargetName="mark" Property="Visibility" Value="Visible"/>
            </Trigger>
            <Trigger Property="IsChecked" Value="{x:Null}">
              <Setter TargetName="box" Property="Background" Value="#2C4A8F"/>
              <Setter TargetName="box" Property="BorderBrush" Value="#3E6FE0"/>
              <Setter TargetName="dash" Property="Visibility" Value="Visible"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="SegmentRadio" TargetType="RadioButton">
    <Setter Property="Foreground" Value="#8791A5"/>
    <Setter Property="Padding" Value="12,3"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#E4E8EF"/></Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="Background" Value="#28303D"/>
              <Setter Property="Foreground" Value="#E4E8EF"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="SegmentHost" TargetType="Border">
    <Setter Property="Background" Value="#161B22"/>
    <Setter Property="BorderBrush" Value="#242B36"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="CornerRadius" Value="8"/>
    <Setter Property="Padding" Value="2"/>
  </Style>

  <Style x:Key="WorkspaceTab" TargetType="RadioButton">
    <Setter Property="Foreground" Value="#8791A5"/>
    <Setter Property="Padding" Value="14,7"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Border x:Name="b" Background="Transparent" CornerRadius="7" Padding="{TemplateBinding Padding}">
            <ContentPresenter VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#E4E8EF"/></Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="Background" Value="#1F2B47"/>
              <Setter Property="Foreground" Value="White"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="NavItem" TargetType="RadioButton">
    <Setter Property="Foreground" Value="#AEB6C4"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Margin" Value="0,1"/>
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Grid>
            <Border x:Name="b" Background="Transparent" CornerRadius="7" Padding="10,7">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
            <Border x:Name="bar" Width="3" CornerRadius="2" Background="#4C7DF0" HorizontalAlignment="Left" Margin="0,8" Visibility="Hidden"/>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="b" Property="Background" Value="#1A2029"/>
              <Setter Property="Foreground" Value="#E4E8EF"/>
            </Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="Background" Value="#1A2640"/>
              <Setter TargetName="bar" Property="Visibility" Value="Visible"/>
              <Setter Property="Foreground" Value="White"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="NavHeader" TargetType="TextBlock">
    <Setter Property="Foreground" Value="#5E6779"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="Margin" Value="10,14,0,5"/>
  </Style>

  <Style x:Key="ItemCard" TargetType="ListBoxItem">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Padding" Value="8,6"/>
    <Setter Property="Margin" Value="0,1"/>
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ListBoxItem">
          <Border x:Name="b" Background="Transparent" BorderBrush="Transparent" BorderThickness="1" CornerRadius="7" Padding="{TemplateBinding Padding}">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#1A2029"/></Trigger>
            <Trigger Property="IsSelected" Value="True">
              <Setter TargetName="b" Property="Background" Value="#1A2640"/>
              <Setter TargetName="b" Property="BorderBrush" Value="#2F4478"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ListBox">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="ItemContainerStyle" Value="{StaticResource ItemCard}"/>
    <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
    <Setter Property="VirtualizingPanel.IsVirtualizing" Value="True"/>
    <Setter Property="VirtualizingPanel.VirtualizationMode" Value="Recycling"/>
  </Style>

  <Style TargetType="ProgressBar">
    <Setter Property="Background" Value="#262D39"/>
    <Setter Property="Foreground" Value="#4C7DF0"/>
    <Setter Property="Height" Value="6"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ProgressBar">
          <Grid>
            <Border x:Name="PART_Track" CornerRadius="3" Background="{TemplateBinding Background}"/>
            <Border x:Name="PART_Indicator" CornerRadius="3" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left"/>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="GridCell" TargetType="DataGridCell">
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="DataGridCell">
          <Border Background="{TemplateBinding Background}" Padding="10,4">
            <ContentPresenter VerticalAlignment="Center"/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
    <Style.Triggers>
      <Trigger Property="IsSelected" Value="True">
        <Setter Property="Background" Value="#233354"/>
        <Setter Property="Foreground" Value="White"/>
      </Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="BoolCell" TargetType="DataGridCell" BasedOn="{StaticResource GridCell}">
    <Style.Triggers>
      <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Content.Text}" Value="Tak"><Setter Property="Foreground" Value="#5EE3AE"/></DataTrigger>
      <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Content.Text}" Value="Nie"><Setter Property="Foreground" Value="#FF7A86"/></DataTrigger>
      <Trigger Property="IsSelected" Value="True">
        <Setter Property="Background" Value="#233354"/>
      </Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="BoolCellInv" TargetType="DataGridCell" BasedOn="{StaticResource GridCell}">
    <Style.Triggers>
      <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Content.Text}" Value="Tak"><Setter Property="Foreground" Value="#FF7A86"/></DataTrigger>
      <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Content.Text}" Value="Nie"><Setter Property="Foreground" Value="#5EE3AE"/></DataTrigger>
      <Trigger Property="IsSelected" Value="True">
        <Setter Property="Background" Value="#233354"/>
      </Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="GridRow" TargetType="DataGridRow">
    <Style.Triggers>
      <DataTrigger Binding="{Binding [__flag]}" Value="crit"><Setter Property="Foreground" Value="#FF7A86"/></DataTrigger>
      <DataTrigger Binding="{Binding [__flag]}" Value="warn"><Setter Property="Foreground" Value="#FFC46B"/></DataTrigger>
      <DataTrigger Binding="{Binding [__flag]}" Value="muted"><Setter Property="Foreground" Value="#7B8496"/></DataTrigger>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#1D2430"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="GridHeader" TargetType="DataGridColumnHeader">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="Foreground" Value="#8791A5"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Padding" Value="10,8"/>
    <Setter Property="BorderBrush" Value="#252C38"/>
    <Setter Property="BorderThickness" Value="0,0,1,1"/>
  </Style>
  <!-- Lejek filtra w nagłówku kolumny: przygaszony, wyraźny po najechaniu na nagłówek, niebieski gdy filtr jest aktywny (Tag = on) -->
  <Style x:Key="HeaderFilterButton" TargetType="Button">
    <Setter Property="Foreground" Value="#7B8496"/>
    <Setter Property="Opacity" Value="0.45"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="VerticalAlignment" Value="Center"/>
    <Setter Property="ToolTip" Value="Filtruj kolumnę"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="Transparent" CornerRadius="4" Padding="4,3">
            <TextBlock Text="&#xE71C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10.5" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#2A3342"/><Setter Property="Foreground" Value="#E4E8EF"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
    <Style.Triggers>
      <DataTrigger Binding="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=DataGridColumnHeader}}" Value="True"><Setter Property="Opacity" Value="1"/></DataTrigger>
      <Trigger Property="Tag" Value="on"><Setter Property="Opacity" Value="1"/><Setter Property="Foreground" Value="#8CB0FF"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="DarkGrid" TargetType="DataGrid">
    <Style.Resources>
      <SolidColorBrush x:Key="{x:Static SystemColors.ControlBrushKey}" Color="#161B22"/>
    </Style.Resources>
    <Setter Property="Background" Value="#161B22"/>
    <Setter Property="Foreground" Value="#D5DAE3"/>
    <Setter Property="RowBackground" Value="#161B22"/>
    <Setter Property="AlternatingRowBackground" Value="#181E26"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="GridLinesVisibility" Value="Horizontal"/>
    <Setter Property="HorizontalGridLinesBrush" Value="#1F2530"/>
    <Setter Property="HeadersVisibility" Value="Column"/>
    <Setter Property="IsReadOnly" Value="True"/>
    <Setter Property="CanUserAddRows" Value="False"/>
    <Setter Property="CanUserDeleteRows" Value="False"/>
    <Setter Property="CanUserResizeRows" Value="False"/>
    <Setter Property="SelectionMode" Value="Extended"/>
    <Setter Property="SelectionUnit" Value="FullRow"/>
    <Setter Property="ClipboardCopyMode" Value="IncludeHeader"/>
    <Setter Property="MinRowHeight" Value="28"/>
    <Setter Property="FontSize" Value="12.5"/>
    <Setter Property="EnableRowVirtualization" Value="True"/>
    <!-- Bez wirtualizacji kolumn: przy przewijaniu w poziomie część nagłówków (z przyciskiem filtra) bywała pusta -->
    <Setter Property="EnableColumnVirtualization" Value="False"/>
    <Setter Property="VirtualizingPanel.VirtualizationMode" Value="Recycling"/>
    <Setter Property="ColumnHeaderStyle" Value="{StaticResource GridHeader}"/>
    <Setter Property="CellStyle" Value="{StaticResource GridCell}"/>
    <Setter Property="RowStyle" Value="{StaticResource GridRow}"/>
  </Style>

  <Style TargetType="ContextMenu">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="BorderBrush" Value="#2F3846"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ContextMenu">
          <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="4">
            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="MenuItem">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="MenuItem">
          <Grid>
            <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="8,6" MinWidth="200">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="26"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <ContentPresenter ContentSource="Icon" VerticalAlignment="Center" TextElement.Foreground="#8791A5"/>
                <ContentPresenter Grid.Column="1" ContentSource="Header" VerticalAlignment="Center"/>
                <TextBlock x:Name="arrow" Grid.Column="2" Text="&#xE76C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10" Foreground="#8791A5" Margin="12,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
              </Grid>
            </Border>
            <!-- Podmenu (np. «Konto Microsoft 365 (N)»): bez tego okienka pozycja z podmenu nie reagowała -->
            <Popup x:Name="PART_Popup" Placement="Right" HorizontalOffset="4" VerticalOffset="-5" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade"
                   IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}">
              <Border Background="#1B212A" BorderBrush="#2F3846" BorderThickness="1" CornerRadius="8" Padding="4">
                <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
              </Border>
            </Popup>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="HasItems" Value="True"><Setter TargetName="arrow" Property="Visibility" Value="Visible"/></Trigger>
            <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="b" Property="Background" Value="#24304A"/></Trigger>
            <Trigger Property="IsSubmenuOpen" Value="True"><Setter TargetName="b" Property="Background" Value="#24304A"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="MenuSeparator" TargetType="Separator">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Separator">
          <Border Height="1" Background="#2A323F" Margin="6,4"/>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ToolTip">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ToolTip">
          <Border Background="#232A35" BorderBrush="#2F3846" BorderThickness="1" CornerRadius="6" Padding="9,6" MaxWidth="460">
            <ContentPresenter>
              <ContentPresenter.Resources>
                <Style TargetType="TextBlock"><Setter Property="TextWrapping" Value="Wrap"/></Style>
              </ContentPresenter.Resources>
            </ContentPresenter>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="TreeView">
    <Style.Resources>
      <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#2A3B63"/>
      <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="White"/>
      <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}" Color="#24304A"/>
      <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightTextBrushKey}" Color="White"/>
    </Style.Resources>
    <Setter Property="Background" Value="#161B22"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderBrush" Value="#242B36"/>
    <Setter Property="Padding" Value="6"/>
  </Style>
  <Style TargetType="TreeViewItem">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Padding" Value="4,3"/>
  </Style>

  <Style TargetType="GridSplitter">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Focusable" Value="False"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#2F4478"/></Trigger>
    </Style.Triggers>
  </Style>

  <Style x:Key="Chip" TargetType="Border">
    <Setter Property="Background" Value="#1E252F"/>
    <Setter Property="CornerRadius" Value="9"/>
    <Setter Property="Padding" Value="9,2"/>
    <Setter Property="Margin" Value="0,0,6,0"/>
    <Setter Property="VerticalAlignment" Value="Center"/>
  </Style>
</ResourceDictionary>
'@
#endregion

#region Stan interfejsu
$script:ThemeDoc = $null
$script:Theme = $null
$script:DwmReady = $null

$script:UI = @{
    Window          = $null
    Controls        = @{}
    Workspaces      = [ordered]@{}
    ModuleDefs      = New-Object System.Collections.ArrayList
    Modules         = @{}
    ActiveWorkspace = $null
    ActiveModule    = $null
    Panels          = @{}
    LogItems        = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
    LogUnread       = 0
    LogVisible      = $false
    DetailVisible   = $true
    BusyDepth       = 0
    ConnectButtons  = @{}
}
$Global:HT_UI = $script:UI

# Kolory kropek stanu (lista obiektów, połączenia)
$script:DotColors = @{ unknown = '#3A4352'; ok = '#5EE3AE'; warn = '#FFC46B'; crit = '#FF7A86'; off = '#5E6779'; info = '#8CC0FF' }
#endregion

#region Podstawy: motyw, XAML, pędzle, ikony
function Get-HTTheme {
    # Jedna instancja słownika - style i pędzle dla kontrolek tworzonych w kodzie
    if (-not $script:Theme) { $script:Theme = [System.Windows.Markup.XamlReader]::Parse($script:ThemeXaml) }
    return $script:Theme
}

function Get-HTThemeResource([string]$Key) {
    return (Get-HTTheme)[$Key]
}

function New-HTUiElement {
    # Ładuje XAML z wstrzykniętym motywem: zasoby muszą istnieć w chwili parsowania (StaticResource),
    # dlatego słownik motywu trafia na początek <Root.Resources> korzenia dokumentu.
    param([Parameter(Mandatory)][string]$Xaml)
    if (-not $script:ThemeDoc) {
        $script:ThemeDoc = New-Object System.Xml.XmlDocument
        $script:ThemeDoc.LoadXml($script:ThemeXaml)
    }
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $false
    $doc.LoadXml($Xaml)
    $root = $doc.DocumentElement
    $resName = $root.LocalName + '.Resources'
    $existing = $null
    foreach ($child in @($root.ChildNodes)) { if ($child.LocalName -eq $resName) { $existing = $child } }
    $dictionary = $doc.ImportNode($script:ThemeDoc.DocumentElement, $true)
    if ($existing) {
        foreach ($child in @($existing.ChildNodes)) { [void]$dictionary.AppendChild($child) }
        [void]$root.RemoveChild($existing)
    }
    $resources = $doc.CreateElement($resName, $root.NamespaceURI)
    [void]$resources.AppendChild($dictionary)
    [void]$root.PrependChild($resources)
    $reader = New-Object System.Xml.XmlNodeReader $doc
    return [System.Windows.Markup.XamlReader]::Load($reader)
}

function Get-HTBrush([string]$Color) {
    $brush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Color))
    $brush.Freeze()
    return $brush
}

function Get-HTGlyph([string]$Code) {
    if (-not $Code) { return '' }
    return [string][char][Convert]::ToInt32($Code, 16)
}

function New-HTGlyphBlock {
    param([string]$Code, [double]$Size = 14, [string]$Color = '')
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Style = Get-HTThemeResource 'Glyph'
    $t.Text = Get-HTGlyph $Code
    $t.FontSize = $Size
    if ($Color) { $t.Foreground = Get-HTBrush $Color }
    return $t
}

function New-HTIconContent {
    # Zawartość przycisku: ikona + tekst
    param([string]$Text, [string]$Icon, [double]$IconSize = 13)
    if (-not $Icon) { return $Text }
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $g = New-HTGlyphBlock -Code $Icon -Size $IconSize
    if ($Text) { $g.Margin = '0,0,8,0' }
    [void]$sp.Children.Add($g)
    if ($Text) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $Text
        $t.VerticalAlignment = 'Center'
        [void]$sp.Children.Add($t)
    }
    return $sp
}

function New-HTButton {
    # -Danger: zmiana (czerwony), -Create: dodawanie / tworzenie (zielony), -Primary: wypełniony
    param([string]$Text, [string]$Icon = '', [switch]$Primary, [switch]$Danger, [switch]$Create, [switch]$Ghost, [string]$ToolTip = '')
    $b = New-Object System.Windows.Controls.Button
    if ($Create) { $b.Style = Get-HTThemeResource $(if ($Primary) { 'CreatePrimaryButton' } else { 'CreateButton' }) }
    elseif ($Primary -and $Danger) { $b.Style = Get-HTThemeResource 'DangerPrimaryButton' }
    elseif ($Primary) { $b.Style = Get-HTThemeResource 'PrimaryButton' }
    elseif ($Danger) { $b.Style = Get-HTThemeResource 'DangerButton' }
    elseif ($Ghost) { $b.Style = Get-HTThemeResource 'GhostButton' }
    $b.Content = New-HTIconContent -Text $Text -Icon $Icon
    if ($ToolTip) { $b.ToolTip = $ToolTip }
    return $b
}

function Set-HTDarkTitleBar {
    # Ciemny pasek tytułu (Windows 10 20H1+ / 11). Brak obsługi - okno zostaje z jasnym paskiem.
    param($Window)
    try {
        if ($null -eq $script:DwmReady) {
            $script:DwmReady = $false
            if (-not ('HelpdeskTools.Dwm' -as [type])) {
                Add-Type -Namespace HelpdeskTools -Name Dwm -ErrorAction Stop -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attribute, ref int value, int size);
'@
            }
            $script:DwmReady = $true
        }
        if (-not $script:DwmReady) { return }
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $Window).Handle
        if ($hwnd -eq [IntPtr]::Zero) { return }
        $on = 1
        if ([HelpdeskTools.Dwm]::DwmSetWindowAttribute($hwnd, 20, [ref]$on, 4) -ne 0) {
            [void][HelpdeskTools.Dwm]::DwmSetWindowAttribute($hwnd, 19, [ref]$on, 4)
        }
        $caption = 0x001D1712   # #12171D jako COLORREF (0x00BBGGRR) - Windows 11
        [void][HelpdeskTools.Dwm]::DwmSetWindowAttribute($hwnd, 35, [ref]$caption, 4)
    }
    catch { Write-Verbose "Ciemny pasek tytułu niedostępny: $_" }
}

function Update-HTUi {
    # Przetwarza zaległe zdarzenia okna (odświeżenie widoku w trakcie dłuższej operacji)
    try {
        $frame = New-Object System.Windows.Threading.DispatcherFrame
        $callback = [System.Windows.Threading.DispatcherOperationCallback] { param($f) $f.Continue = $false; return $null }
        [void][System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, $callback, $frame)
        [System.Windows.Threading.Dispatcher]::PushFrame($frame)
    }
    catch { Write-Verbose "Update-HTUi: $_" }
}

function Get-HTObjectValue {
    param($InputObject, [string]$Name)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Data.DataRowView]) { $InputObject = $InputObject.Row }
    if ($InputObject -is [System.Data.DataRow]) {
        if (-not $InputObject.Table.Columns.Contains($Name)) { return $null }
        $v = $InputObject[$Name]
        if ($v -is [System.DBNull]) { return $null }
        return $v
    }
    if ($InputObject -is [System.Collections.IDictionary]) { return $InputObject[$Name] }
    $p = $InputObject.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}

function ConvertTo-HTCellValue {
    # Wartość do tabeli: liczby zostają liczbami (sortowanie), daty -> tekst ISO, bool -> Tak/Nie, kolekcje -> tekst
    param($Value)
    if ($null -eq $Value) { return [System.DBNull]::Value }
    if ($Value -is [System.Management.Automation.PSObject]) { $Value = $Value.PSObject.BaseObject }
    if ($Value -is [string]) {
        $display = ConvertTo-HTDisplayValue $Value
        return $display
    }
    if ($Value -is [bool]) { if ($Value) { return 'Tak' } else { return 'Nie' } }
    if ($Value -is [datetime]) {
        if ($Value.Year -lt 1700) { return [System.DBNull]::Value }
        return $Value.ToString('yyyy-MM-dd HH:mm')
    }
    if ($Value -is [datetimeoffset]) { return $Value.LocalDateTime.ToString('yyyy-MM-dd HH:mm') }
    if ($Value -is [enum] -or $Value -is [timespan] -or $Value -is [guid] -or $Value -is [char]) { return [string]$Value }
    if ($Value -is [System.ValueType]) { return $Value }
    return (ConvertTo-HTDisplayValue $Value)
}
#endregion

#region Okna dialogowe
$script:DialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="480" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterOwner"
        ShowInTaskbar="False" Background="#12171D" Foreground="#E4E8EF" FontFamily="Segoe UI" FontSize="13"
        UseLayoutRounding="True" SnapsToDevicePixels="True" TextOptions.TextFormattingMode="Display">
  <Grid Background="#12171D">
  <Grid Margin="22,20,22,18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid Margin="0,0,0,16">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border x:Name="dlgIconTile" Width="38" Height="38" CornerRadius="10" Background="#1A2640" Margin="0,0,14,0" VerticalAlignment="Top">
        <TextBlock x:Name="dlgIcon" Style="{StaticResource Glyph}" FontSize="17" Foreground="#8CB0FF" HorizontalAlignment="Center"/>
      </Border>
      <StackPanel Grid.Column="1" VerticalAlignment="Center">
        <TextBlock x:Name="dlgTitle" FontSize="16" FontWeight="SemiBold" Foreground="White" TextWrapping="Wrap"/>
        <TextBlock x:Name="dlgSubtitle" Foreground="#8791A5" TextWrapping="Wrap" Margin="0,3,0,0"/>
      </StackPanel>
    </Grid>
    <Grid x:Name="dlgBody" Grid.Row="1">
<!--BODY-->
    </Grid>
    <Grid Grid.Row="2" Margin="0,18,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <!-- Przyciski dodatkowe w osobnej kolumnie: przy wąskim oknie zawijają się, zamiast nachodzić na OK / Anuluj -->
      <WrapPanel x:Name="dlgExtra" Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="0,0,12,0"/>
      <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom">
        <Button x:Name="btnCancel" Content="Anuluj" MinWidth="96" IsCancel="True"/>
        <Button x:Name="btnOk" Content="OK" MinWidth="96" Margin="8,0,0,0" Style="{StaticResource PrimaryButton}" IsDefault="True"/>
      </StackPanel>
    </Grid>
  </Grid>
  </Grid>
</Window>
'@

$script:DialogTones = @{
    info = @{ Back = '#1A2640'; Fore = '#8CB0FF'; Icon = 'E946' }
    ok   = @{ Back = '#15291F'; Fore = '#5EE3AE'; Icon = 'E930' }
    warn = @{ Back = '#2E2616'; Fore = '#FFC46B'; Icon = 'E7BA' }
    crit = @{ Back = '#2E1A1E'; Fore = '#FF7A86'; Icon = 'EA39' }
}

$script:DialogEvents = @{
    Ok     = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if (-not $w) { return }
        $validate = $w.Tag.Validate
        if ($validate) {
            $ok = $false
            try { $ok = [bool](& $validate $w) }
            catch { Show-HTError 'Nie można zatwierdzić.' $_; return }
            if (-not $ok) { return }
        }
        Close-HTDialog -Window $w -Ok $true
    }
    Cancel = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if (-not $w) { return }
        $w.Tag.Result = $false
        if (-not $w.Tag.Modal) { $w.Close() }
    }
}

function New-HTDialog {
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Subtitle = '',
        [string]$Body = '',
        [ValidateSet('info', 'ok', 'warn', 'crit')][string]$Tone = 'info',
        [string]$Icon = '',
        [double]$Width = 480,
        [double]$Height = 0,
        [string]$OkText = 'OK',
        [string]$CancelText = 'Anuluj',
        [switch]$NoCancel,
        [switch]$Danger,
        [switch]$Resizable,
        [scriptblock]$Validate
    )
    $w = New-HTUiElement ($script:DialogXaml.Replace('<!--BODY-->', $Body))
    $w.Title = $Title
    $w.Width = $Width
    if ($Height -gt 0) {
        $w.SizeToContent = 'Manual'
        $w.Height = $Height
    }
    if ($Resizable) {
        $w.ResizeMode = 'CanResizeWithGrip'
        $w.MinWidth = [Math]::Min($Width, 420)
        $w.MinHeight = 260
    }
    $toneDef = $script:DialogTones[$Tone]
    $w.FindName('dlgIconTile').Background = Get-HTBrush $toneDef.Back
    $iconBlock = $w.FindName('dlgIcon')
    $iconBlock.Foreground = Get-HTBrush $toneDef.Fore
    $iconBlock.Text = Get-HTGlyph $(if ($Icon) { $Icon } else { $toneDef.Icon })
    $w.FindName('dlgTitle').Text = $Title
    $sub = $w.FindName('dlgSubtitle')
    if ($Subtitle) { $sub.Text = $Subtitle } else { $sub.Visibility = 'Collapsed' }
    $ok = $w.FindName('btnOk')
    $ok.Content = $OkText
    if ($Danger) { $ok.Style = Get-HTThemeResource 'DangerPrimaryButton' }
    $cancel = $w.FindName('btnCancel')
    $cancel.Content = $CancelText
    if ($NoCancel) {
        $cancel.Visibility = 'Collapsed'
        $ok.IsCancel = $true
    }
    $ok.add_Click($script:DialogEvents.Ok)
    $cancel.add_Click($script:DialogEvents.Cancel)
    $w.Tag = @{ Result = $false; Modal = $false; Validate = $Validate; Tone = $Tone }
    return $w
}

function Invoke-HTDialog {
    # Pokazuje okno modalnie nad oknem głównym; zwraca $true, gdy zatwierdzono
    param([Parameter(Mandatory)][System.Windows.Window]$Window)
    if (-not ($Window.Tag -is [hashtable])) { $Window.Tag = @{} }
    # Przegląd modułów (autotest): okno nie pokazuje się - zapis treści i odpowiedź «Anuluj» (bez zmian)
    if ($null -ne $script:UI.DialogCapture -and -not $Window.Tag['LockScreen']) {
        $texts = @('dlgSubtitle', 'msgText') | ForEach-Object { $Window.FindName($_) } | Where-Object { $_ -and $_.Text } | ForEach-Object { [string]$_.Text }
        $script:UI.DialogCapture.Add([PSCustomObject]@{ Title = [string]$Window.Title; Text = ($texts -join ' '); Tone = [string]$Window.Tag['Tone'] })
        $Window.Tag['Result'] = $false
        try { $Window.Close() } catch { Write-Verbose $_ }
        return $false
    }
    # Program zablokowany: okno (inne niż ekran PIN) pokaże się dopiero po odblokowaniu
    if ($script:LockState.Locked -and -not $Window.Tag['LockScreen']) { Wait-HTUnlocked }
    # Program zamykany awaryjnie z ekranu blokady: kolejne okna już się nie pokazują
    if ($script:LockState.Emergency -and -not $Window.Tag['LockScreen']) { $Window.Tag['Result'] = $false; return $false }
    if (-not $Window.Tag['LockScreen']) { Register-HTIdleActivity -Window $Window }
    $Window.Tag['Result'] = $false
    $Window.Tag['Modal'] = $true
    $main = $script:UI.Window
    if ($main -and $main.IsVisible -and -not [object]::ReferenceEquals($main, $Window)) { $Window.Owner = $main }
    else {
        $Window.WindowStartupLocation = 'CenterScreen'
        $Window.Topmost = $true
    }
    $Window.add_SourceInitialized({ param($s, $e) Set-HTDarkTitleBar $s })
    [void]$Window.ShowDialog()
    return [bool]$Window.Tag.Result
}

function Close-HTDialog {
    param([Parameter(Mandatory)]$Window, [bool]$Ok)
    $Window.Tag.Result = $Ok
    if ($Window.Tag.Modal) {
        try { $Window.DialogResult = $Ok } catch { try { $Window.Close() } catch { Write-Verbose $_ } }
    }
    else {
        try { $Window.Close() } catch { Write-Verbose $_ }
    }
}

function New-HTDialogText {
    # Akapit tekstu do treści okna (zawijany)
    param([string]$Text, [string]$Color = '#C9D0DC', [double]$Size = 13)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.TextWrapping = 'Wrap'
    $t.Foreground = Get-HTBrush $Color
    $t.FontSize = $Size
    return $t
}

function Show-HTMessage {
    param([string]$Text, [string]$Title = 'Helpdesk Tools', [ValidateSet('info', 'ok', 'warn', 'crit')][string]$Tone = 'info')
    $body = @'
<ScrollViewer MaxHeight="420" VerticalScrollBarVisibility="Auto">
  <TextBlock x:Name="msgText" TextWrapping="Wrap" Foreground="#C9D0DC" LineHeight="19"/>
</ScrollViewer>
'@
    $w = New-HTDialog -Title $Title -Body $body -Tone $Tone -NoCancel -Width 500
    $w.FindName('msgText').Text = $Text
    [void](Invoke-HTDialog $w)
}

function Show-HTWarning([string]$Text, [string]$Title = 'Uwaga') {
    Show-HTMessage -Text $Text -Title $Title -Tone 'warn'
}

function Show-HTError {
    param([string]$Text, $ErrorObject = $null)
    $detail = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) { $ErrorObject.Exception.Message }
    elseif ($ErrorObject -is [System.Exception]) { $ErrorObject.Message }
    elseif ($ErrorObject) { [string]$ErrorObject }
    else { '' }
    if ($detail -and (Get-Command -Name Compress-HTErrorText -ErrorAction Ignore)) { $detail = Compress-HTErrorText -Text $detail }
    $message = if ($detail) { "$Text`r`n`r`n$detail" } else { $Text }
    Show-HTMessage -Text $message -Title 'Błąd' -Tone 'crit'
}

# Zgodność z wcześniejszym API (MessageBox): zwraca 'OK', 'Cancel', 'Yes' albo 'No'
function Show-Dialog {
    param (
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("OK", "OKCancel", "YesNo", "YesNoCancel")][string]$Buttons = "OK",
        [ValidateSet("Info", "Error", "Warning", "Question")][string]$Type = "Info",
        [string]$Title = "Helpdesk Tools"
    )
    $tone = switch ($Type) { "Error" { 'crit' } "Warning" { 'warn' } default { 'info' } }
    $icon = if ($Type -eq 'Question') { 'E9CE' } else { '' }
    if ($Buttons -eq 'OK') {
        Show-HTMessage -Text $Message -Title $Title -Tone $tone
        return 'OK'
    }
    $yesNo = $Buttons -like 'YesNo*'
    $body = '<TextBlock x:Name="msgText" TextWrapping="Wrap" Foreground="#C9D0DC" LineHeight="19"/>'
    $w = New-HTDialog -Title $Title -Body $body -Tone $tone -Icon $icon -Width 500 `
        -OkText $(if ($yesNo) { 'Tak' } else { 'OK' }) -CancelText $(if ($yesNo) { 'Nie' } else { 'Anuluj' })
    $w.FindName('msgText').Text = $Message
    $ok = Invoke-HTDialog $w
    if ($yesNo) { if ($ok) { return 'Yes' } else { return 'No' } }
    if ($ok) { return 'OK' } else { return 'Cancel' }
}

function Show-HTConfirm {
    <#
        Pytanie z (opcjonalną) listą obiektów, których dotyczy operacja. Zwraca $true/$false.
        -TypeToConfirm: operacja nieodwracalna - użytkownik musi przepisać podany tekst.
        -Details: co zostanie zrobione (osobna karta nad listą obiektów), -ItemsHeader: nagłówek listy obiektów.
    #>
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = 'Potwierdzenie',
        [string[]]$Items = @(),
        [string]$ConfirmText = 'Wykonaj',
        [string]$TypeToConfirm = '',
        [string[]]$Details = @(),
        [string]$DetailsHeader = 'Co zostanie zrobione',
        [string]$ItemsHeader = '',
        [switch]$Warning,
        [switch]$Danger
    )
    $body = @'
<StackPanel>
  <TextBlock x:Name="cfText" TextWrapping="Wrap" Foreground="#C9D0DC" LineHeight="19"/>
  <TextBlock x:Name="cfDetailsHeader" Foreground="#8CB0FF" FontSize="12.5" FontWeight="SemiBold" Margin="0,14,0,5" Visibility="Collapsed"/>
  <Border x:Name="cfDetailsHost" Style="{StaticResource Card}" Padding="12,8" Visibility="Collapsed">
    <ScrollViewer MaxHeight="200" VerticalScrollBarVisibility="Auto">
      <TextBlock x:Name="cfDetails" Foreground="#E4E8EF" FontSize="12.5" LineHeight="19" TextWrapping="Wrap"/>
    </ScrollViewer>
  </Border>
  <TextBlock x:Name="cfListHeader" Foreground="#8CB0FF" FontSize="12.5" FontWeight="SemiBold" Margin="0,14,0,5" Visibility="Collapsed"/>
  <Border x:Name="cfListHost" Style="{StaticResource Card}" Padding="12,8" Margin="0,14,0,0" Visibility="Collapsed">
    <ScrollViewer MaxHeight="220" VerticalScrollBarVisibility="Auto">
      <TextBlock x:Name="cfList" Foreground="#AEB6C4" FontSize="12.5" LineHeight="19" TextWrapping="Wrap"/>
    </ScrollViewer>
  </Border>
  <StackPanel x:Name="cfTypeHost" Margin="0,14,0,0" Visibility="Collapsed">
    <TextBlock x:Name="cfTypeLabel" Foreground="#8791A5" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,5"/>
    <TextBox x:Name="cfType"/>
  </StackPanel>
</StackPanel>
'@
    $tone = if ($Danger) { 'crit' } elseif ($Warning) { 'warn' } else { 'info' }
    $w = New-HTDialog -Title $Title -Body $body -Tone $tone -Icon $(if (-not $Danger -and -not $Warning) { 'E9CE' } else { '' }) -OkText $ConfirmText -Danger:$Danger -Width $(if (@($Details).Count) { 580 } else { 520 }) -Validate {
        param($w)
        $expected = $w.Tag.TypeToConfirm
        if ($expected -and $w.FindName('cfType').Text.Trim() -ne $expected) {
            Show-HTWarning "Aby potwierdzić, wpisz dokładnie: $expected"
            return $false
        }
        return $true
    }
    $w.Tag.TypeToConfirm = $TypeToConfirm
    $w.FindName('cfText').Text = $Message
    $Details = @($Details | Where-Object { "$_".Trim() })
    if ($Details.Count -gt 0) {
        $w.FindName('cfDetailsHeader').Text = $DetailsHeader
        $w.FindName('cfDetailsHeader').Visibility = 'Visible'
        $w.FindName('cfDetails').Text = ($Details | ForEach-Object { "•  $_" }) -join "`n"
        $w.FindName('cfDetailsHost').Visibility = 'Visible'
    }
    if ($Items.Count -gt 0) {
        $shown = @($Items | Select-Object -First 30)
        $text = ($shown | ForEach-Object { "•  $_" }) -join "`n"
        if ($Items.Count -gt $shown.Count) { $text += "`n… i $($Items.Count - $shown.Count) więcej" }
        $w.FindName('cfList').Text = $text
        $w.FindName('cfListHost').Visibility = 'Visible'
        if ($ItemsHeader) {
            $w.FindName('cfListHeader').Text = $ItemsHeader
            $w.FindName('cfListHeader').Visibility = 'Visible'
            $w.FindName('cfListHost').Margin = '0'
        }
    }
    if ($TypeToConfirm) {
        $w.FindName('cfTypeLabel').Text = "Operacja jest nieodwracalna. Aby kontynuować, wpisz: $TypeToConfirm"
        $w.FindName('cfTypeHost').Visibility = 'Visible'
        $w.add_ContentRendered({ param($s, $e) [void]$s.FindName('cfType').Focus() })
    }
    return (Invoke-HTDialog $w)
}

function Show-InputBox {
    # Pole tekstowe w oknie; zwraca tekst albo $null (anulowano)
    param (
        [Parameter(Mandatory)][string]$Prompt,
        [string]$Title = "Wprowadź wartość",
        [ValidateSet("Text", "Email", "Phone", "Url", "Upn", "Guid")][string]$ValidationType = "Text",
        [string]$DefaultText = "",
        [string]$Placeholder = "",
        [switch]$AllowEmpty,
        [switch]$Password,
        [switch]$Multiline,
        [string]$Icon = 'E70F'
    )
    $body = if ($Password) { '<PasswordBox x:Name="inPass"/>' }
    elseif ($Multiline) { '<TextBox x:Name="inText" Style="{StaticResource MultiText}" MinHeight="220"/>' }
    else { '<TextBox x:Name="inText"/>' }
    $w = New-HTDialog -Title $Title -Subtitle $Prompt -Body $body -Icon $Icon -Width $(if ($Multiline) { 620 } else { 500 }) -Height $(if ($Multiline) { 470 } else { 0 }) -Resizable:$Multiline -Validate {
        param($w)
        $value = if ($w.Tag.Password) { $w.FindName('inPass').Password } else { $w.FindName('inText').Text.Trim() }
        if (-not $value) {
            if ($w.Tag.AllowEmpty) { return $true }
            Show-HTWarning 'Pole nie może być puste.'
            return $false
        }
        if (-not $w.Tag.Multiline -and -not (Test-HTInputValue -Value $value -ValidationType $w.Tag.ValidationType)) {
            $messages = @{
                Text = 'Pole nie może być puste.'; Email = 'Nieprawidłowy adres e-mail.'; Upn = 'Nieprawidłowa nazwa UPN (np. jan.kowalski@firma.pl).'
                Phone = 'Nieprawidłowy numer telefonu.'; Url = 'Nieprawidłowy adres URL (https://...).'; Guid = 'Nieprawidłowy identyfikator GUID.'
            }
            Show-HTWarning $messages[$w.Tag.ValidationType]
            return $false
        }
        return $true
    }
    $w.Tag.ValidationType = $ValidationType
    $w.Tag.AllowEmpty = [bool]$AllowEmpty
    $w.Tag.Password = [bool]$Password
    $w.Tag.Multiline = [bool]$Multiline
    if ($Password) {
        $w.add_ContentRendered({ param($s, $e) [void]$s.FindName('inPass').Focus() })
    }
    else {
        $box = $w.FindName('inText')
        $box.Text = $DefaultText
        if ($Placeholder) { $box.Tag = $Placeholder }
        if ($Multiline) { $w.FindName('btnOk').IsDefault = $false }
        $w.add_ContentRendered({ param($s, $e) $b = $s.FindName('inText'); [void]$b.Focus(); $b.SelectAll() })
    }
    if (-not (Invoke-HTDialog $w)) { return $null }
    if ($Password) { return $w.FindName('inPass').Password }
    return $w.FindName('inText').Text.Trim()
}

$script:FormEvents = @{
    Dependency   = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if ($w -and $w.Tag -is [hashtable] -and $w.Tag.Controls) { Update-HTFormDependents -Controls $w.Tag.Controls }
    }
    NumericInput = {
        param($s, $e)
        if ($e.Text -notmatch '^\d+$') { $e.Handled = $true }
    }
    # Formularz z sekcjami: kliknięcie sekcji po lewej pokazuje jej stronę
    Section      = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if (-not $w) { return }
        foreach ($page in $w.Tag.Pages) { $page.Visibility = if ([object]::ReferenceEquals($page, $s.Tag)) { 'Visible' } else { 'Collapsed' } }
        $scroll = $w.FindName('fmScroll')
        if ($scroll) { $scroll.ScrollToTop() }
    }
    # Przyciski w formularzu i pod nim: -OnClick { param($w) }
    Button       = {
        param($s, $e)
        try { $null = & $s.Tag ([System.Windows.Window]::GetWindow($s)) }
        catch {
            Write-Log -Message "Błąd: $($_.Exception.Message)" -Type 'Error'
            Write-HTDebug { "Stos błędu ($($_.Exception.GetType().FullName)):`n$($_.ScriptStackTrace)" }
            Show-HTError 'Operacja nie powiodła się.' $_
        }
    }
}

function Get-HTFormFieldError {
    # Komunikat o błędzie pola formularza albo pusty tekst (pole poprawne)
    param([Parameter(Mandatory)][hashtable]$Entry)
    # Pole ukryte warunkiem ShowWhen nie jest sprawdzane
    if ($Entry.Hidden) { return '' }
    $f = $Entry.Field
    $value = Get-HTFormControlValue -Entry $Entry
    $label = [string]$f.Label
    switch ($Entry.Type) {
        { $_ -in 'Text', 'Password', 'Multiline', 'Combo' } {
            if ($f.Required -and -not "$value") { return "Pole '$label' jest wymagane." }
            if ("$value" -and $f.Validation -and -not (Test-HTInputValue -Value "$value" -ValidationType $f.Validation)) { return "Pole '$label' ma nieprawidłowy format." }
        }
        'Number' {
            $n = 0
            if (-not [int]::TryParse($Entry.Control.Text.Trim(), [ref]$n)) { return "Pole '$label' musi być liczbą." }
            if ($null -ne $f.Min -and $n -lt $f.Min) { return "Pole '$label': minimalna wartość to $($f.Min)." }
            if ($null -ne $f.Max -and $n -gt $f.Max) { return "Pole '$label': maksymalna wartość to $($f.Max)." }
        }
        'Date' {
            $text = $Entry.Control.Text.Trim()
            if (-not $text) { if ($f.Optional) { return '' }; return "Pole '$label' jest wymagane." }
            $d = [datetime]::MinValue
            $formats = [string[]]@('yyyy-MM-dd HH:mm', 'yyyy-MM-dd', 'yyyy-MM-dd H:mm')
            if (-not [datetime]::TryParseExact($text, $formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return "Pole '$label': podaj datę w formacie RRRR-MM-DD GG:MM." }
        }
    }
    return ''
}

function New-HTFormButtons {
    # Rząd przycisków: @(@{ Text; Icon; OnClick = { param($w) }; ToolTip; Danger; Create })
    param([object[]]$Buttons = @())
    $panel = New-Object System.Windows.Controls.WrapPanel
    foreach ($def in @($Buttons | Where-Object { $_ })) {
        $b = New-HTButton -Text ([string]$def.Text) -Icon ([string]$def.Icon) -ToolTip ([string]$def.ToolTip) -Danger:([bool]$def.Danger) -Create:([bool]$def.Create)
        $b.Margin = '0,3,8,3'
        $b.Tag = $def.OnClick
        $b.add_Click($script:FormEvents.Button)
        [void]$panel.Children.Add($b)
    }
    return $panel
}

function Show-HTFormDialog {
    <#
        Formularz w oknie. -Fields: tablica hashtabel:
          @{ Name; Label; Type = Text|Password|Multiline|Combo|Check|Date|Number|Info|Header|Buttons; Default; Options;
             Required; Validation; Editable; Optional; DateOnly; Min; Max; Placeholder; Hint;
             ShowWhen = @{ Field = 'Tryb'; Values = @('Scheduled') } - pole widoczne tylko przy tych wartościach innego pola }
        Buttons: @{ Type = 'Buttons'; Buttons = @(@{ Text; Icon; OnClick = { param($w) } }) } - przyciski w treści formularza.
        -Sections: każdy Header zaczyna sekcję (lista sekcji po lewej, Icon - ikona sekcji, Hint - opis sekcji);
        okno ma stałą wysokość (-MaxHeight), a błąd walidacji przełącza na sekcję z błędnym polem.
        Zwraca słownik Name -> wartość albo $null (anulowano).
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Fields,
        [string]$Description = '',
        [string]$OkText = 'Zapisz',
        [string]$Icon = 'E70F',
        [double]$Width = 560,
        [double]$MaxHeight = 560,
        [switch]$Danger,
        [switch]$Sections,
        # Dodatkowe przyciski po lewej stronie: @{ Text; Icon; OnClick = { param($w) } }
        [object[]]$ExtraButtons = @()
    )
    $body = if ($Sections) {
        @'
<Grid Height="{0}">
  <Grid.ColumnDefinitions>
    <ColumnDefinition Width="236"/>
    <ColumnDefinition Width="*"/>
  </Grid.ColumnDefinitions>
  <Border BorderBrush="#242B36" BorderThickness="0,0,1,0" Padding="0,0,10,0" Margin="0,0,20,0">
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel x:Name="fmNav"/></ScrollViewer>
  </Border>
  <ScrollViewer x:Name="fmScroll" Grid.Column="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><Grid x:Name="fmPages" Margin="0,0,8,0"/></ScrollViewer>
</Grid>
'@ -f [int]$MaxHeight
    }
    else { '<ScrollViewer MaxHeight="{0}" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="fmHost" Margin="0,0,6,0"/></ScrollViewer>' -f [int]$MaxHeight }
    $w = New-HTDialog -Title $Title -Subtitle $Description -Body $body -Icon $Icon -OkText $OkText -Width $Width -Danger:$Danger -Validate {
        param($w)
        foreach ($entry in $w.Tag.Controls.Values) {
            $message = Get-HTFormFieldError -Entry $entry
            if (-not $message) { continue }
            # Pole w innej sekcji - przejście do niej przed komunikatem
            if ($entry.Nav) { $entry.Nav.IsChecked = $true }
            try { [void]$entry.Control.Focus() } catch { Write-Verbose $_ }
            Show-HTWarning $message
            return $false
        }
        return $true
    }
    $pages = New-Object System.Collections.Generic.List[object]
    $w.Tag.Pages = $pages
    $navGroup = 'fm_' + [guid]::NewGuid().ToString('N')
    $nav = $null
    $stack = $null
    $newPage = {
        param([string]$PageTitle, [string]$PageIcon, [string]$PageHint)
        $page = New-Object System.Windows.Controls.StackPanel
        $page.Visibility = if ($pages.Count -eq 0) { 'Visible' } else { 'Collapsed' }
        [void]$w.FindName('fmPages').Children.Add($page)
        $pages.Add($page)
        $rb = New-Object System.Windows.Controls.RadioButton
        $rb.Style = Get-HTThemeResource 'NavItem'
        $rb.GroupName = $navGroup
        $rb.Tag = $page
        $rb.IsChecked = ($pages.Count -eq 1)
        # Siatka zamiast poziomego StackPanel - tekst dostaje szerokość kolumny i zawija się zamiast ucinać
        $row = New-Object System.Windows.Controls.Grid
        $iconColumn = New-Object System.Windows.Controls.ColumnDefinition
        $iconColumn.Width = [System.Windows.GridLength]::Auto
        [void]$row.ColumnDefinitions.Add($iconColumn)
        [void]$row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
        $glyph = New-HTGlyphBlock -Code $(if ($PageIcon) { $PageIcon } else { 'E713' }) -Size 14
        $glyph.Margin = '2,0,11,0'
        $glyph.Width = 18
        $glyph.VerticalAlignment = 'Center'
        [void]$row.Children.Add($glyph)
        $text = New-Object System.Windows.Controls.TextBlock
        $text.Text = $PageTitle
        $text.TextWrapping = 'Wrap'
        $text.VerticalAlignment = 'Center'
        [System.Windows.Controls.Grid]::SetColumn($text, 1)
        [void]$row.Children.Add($text)
        $rb.Content = $row
        $rb.HorizontalContentAlignment = 'Stretch'
        $rb.ToolTip = $PageTitle
        $rb.add_Checked($script:FormEvents.Section)
        [void]$w.FindName('fmNav').Children.Add($rb)
        $heading = New-HTDialogText -Text $PageTitle -Color '#FFFFFF' -Size 15
        $heading.FontWeight = 'SemiBold'
        [void]$page.Children.Add($heading)
        if ($PageHint) {
            $desc = New-HTDialogText -Text $PageHint -Color '#7B8496' -Size 12
            $desc.Margin = '0,3,0,0'
            [void]$page.Children.Add($desc)
        }
        $line = New-Object System.Windows.Controls.Border
        $line.Height = 1
        $line.Background = Get-HTBrush '#242B36'
        $line.Margin = '0,8,0,6'
        [void]$page.Children.Add($line)
        return @{ Page = $page; Nav = $rb }
    }
    if (-not $Sections) { $stack = $w.FindName('fmHost') }
    $controls = [ordered]@{}
    $first = $true
    foreach ($f in $Fields) {
        if (-not $f) { continue }
        $type = if ($f.Type) { [string]$f.Type } else { 'Text' }
        if ($Sections -and ($type -eq 'Header' -or -not $stack)) {
            $created = if ($type -eq 'Header') { & $newPage ([string]$f.Label) ([string]$f.Icon) ([string]$f.Hint) } else { & $newPage 'Ogólne' 'E713' '' }
            $stack = $created.Page
            $nav = $created.Nav
            $first = $true
            if ($type -eq 'Header') { continue }
        }
        if ($type -eq 'Header') {
            $hd = New-HTDialogText -Text ([string]$f.Label) -Color '#8CB0FF' -Size 13.5
            $hd.FontWeight = 'SemiBold'
            $hd.Margin = $(if ($first) { '0,0,0,2' } else { '0,20,0,2' })
            [void]$stack.Children.Add($hd)
            $line = New-Object System.Windows.Controls.Border
            $line.Height = 1
            $line.Background = Get-HTBrush '#242B36'
            $line.Margin = '0,4,0,4'
            [void]$stack.Children.Add($line)
            $first = $true
            continue
        }
        if ($type -eq 'Info') {
            $info = New-HTDialogText -Text ([string]$f.Label) -Color '#7B8496' -Size 12
            $info.Margin = $(if ($first) { '0,0,0,4' } else { '0,12,0,4' })
            [void]$stack.Children.Add($info)
            $first = $false
            continue
        }
        if ($type -eq 'Buttons') {
            if ($f.Label) {
                $bl = New-HTDialogText -Text ([string]$f.Label) -Color '#8791A5' -Size 12
                $bl.Margin = $(if ($first) { '0,0,0,4' } else { '0,14,0,4' })
                [void]$stack.Children.Add($bl)
            }
            $buttons = New-HTFormButtons -Buttons @($f.Buttons)
            $buttons.Margin = $(if ($first -or $f.Label) { '0,0,0,0' } else { '0,12,0,0' })
            [void]$stack.Children.Add($buttons)
            $first = $false
            continue
        }
        $fieldElements = New-Object System.Collections.Generic.List[object]
        if ($type -ne 'Check') {
            $caption = [string]$f.Label + $(if ($f.Required) { ' *' } else { '' })
            $lbl = New-HTDialogText -Text $caption -Color '#8791A5' -Size 12
            $lbl.Margin = $(if ($first) { '0,0,0,5' } else { '0,12,0,5' })
            [void]$stack.Children.Add($lbl)
            $fieldElements.Add($lbl)
        }
        $ctl = $null
        switch ($type) {
            'Combo' {
                $ctl = New-Object System.Windows.Controls.ComboBox
                foreach ($i in @($f.Options)) { if ($null -ne $i) { [void]$ctl.Items.Add([string]$i) } }
                if ($f.Editable) { $ctl.IsEditable = $true; $ctl.Text = [string]$f.Default }
                $index = if ($null -ne $f.Default) { $ctl.Items.IndexOf([string]$f.Default) } else { -1 }
                if ($index -ge 0) { $ctl.SelectedIndex = $index }
                elseif (-not $f.Editable -and $ctl.Items.Count -gt 0) { $ctl.SelectedIndex = 0 }
            }
            'Check' {
                $ctl = New-Object System.Windows.Controls.CheckBox
                $cbText = New-Object System.Windows.Controls.TextBlock
                $cbText.Text = [string]$f.Label
                $cbText.TextWrapping = 'Wrap'
                $ctl.Content = $cbText
                $ctl.IsChecked = [bool]$f.Default
                $ctl.Margin = $(if ($first) { '0,0,0,0' } else { '0,12,0,0' })
            }
            'Multiline' {
                $ctl = New-Object System.Windows.Controls.TextBox
                $ctl.Style = Get-HTThemeResource 'MultiText'
                $ctl.FontFamily = 'Segoe UI'
                $ctl.FontSize = 13
                $ctl.TextWrapping = 'Wrap'
                $ctl.Height = $(if ($f.Height) { [double]$f.Height } else { 110 })
                $ctl.Text = [string]$f.Default
                # Tekst z wcięciami (np. struktura folderów): czcionka o stałej szerokości, Tab wstawia wcięcie, bez zawijania
                if ($f.Monospace) { $ctl.FontFamily = 'Consolas'; $ctl.AcceptsTab = $true; $ctl.TextWrapping = 'NoWrap'; $ctl.HorizontalScrollBarVisibility = 'Auto' }
            }
            'Password' {
                $ctl = New-Object System.Windows.Controls.PasswordBox
                if ($f.Default) { $ctl.Password = [string]$f.Default }
            }
            'Number' {
                $ctl = New-Object System.Windows.Controls.TextBox
                $ctl.Width = 130
                $ctl.HorizontalAlignment = 'Left'
                $ctl.HorizontalContentAlignment = 'Right'
                $ctl.Text = $(if ($null -ne $f.Default) { [string]$f.Default } elseif ($null -ne $f.Min) { [string]$f.Min } else { '0' })
                $ctl.add_PreviewTextInput($script:FormEvents.NumericInput)
            }
            'Date' {
                $ctl = New-Object System.Windows.Controls.TextBox
                $ctl.Width = 200
                $ctl.HorizontalAlignment = 'Left'
                $format = if ($f.DateOnly) { 'yyyy-MM-dd' } else { 'yyyy-MM-dd HH:mm' }
                $ctl.Tag = $(if ($f.DateOnly) { 'RRRR-MM-DD' } else { 'RRRR-MM-DD GG:MM' })
                if ($f.Default -is [datetime]) { $ctl.Text = $f.Default.ToString($format) }
                elseif ($f.Default) { $ctl.Text = [string]$f.Default }
            }
            default {
                $ctl = New-Object System.Windows.Controls.TextBox
                $ctl.Text = [string]$f.Default
            }
        }
        if ($f.Placeholder -and $ctl -is [System.Windows.Controls.TextBox]) { $ctl.Tag = [string]$f.Placeholder }
        if ($f.ToolTip) { $ctl.ToolTip = [string]$f.ToolTip }
        [void]$stack.Children.Add($ctl)
        $fieldElements.Add($ctl)
        if ($f.Hint) {
            $hint = New-HTDialogText -Text ([string]$f.Hint) -Color '#6B7487' -Size 11.5
            $hint.Margin = '1,5,0,0'
            [void]$stack.Children.Add($hint)
            $fieldElements.Add($hint)
        }
        $controls[[string]$f.Name] = @{ Type = $type; Control = $ctl; Field = $f; Nav = $nav; Elements = $fieldElements.ToArray(); Hidden = $false }
        $first = $false
    }
    $w.Tag.Controls = $controls
    # Pola zależne (ShowWhen): widoczne tylko przy wybranych wartościach innego pola
    $hasDependents = $false
    foreach ($entry in @($controls.Values)) {
        $condition = $entry.Field.ShowWhen
        if (-not $condition -or -not $controls.Contains([string]$condition.Field)) { continue }
        $source = $controls[[string]$condition.Field]
        $entry.ShowWhen = @{ Source = $source; Values = @($condition.Values | ForEach-Object { [string]$_ }) }
        if (-not $source.Watched) {
            $source.Watched = $true
            switch ($source.Type) {
                'Combo' { $source.Control.add_SelectionChanged($script:FormEvents.Dependency); if ($source.Control.IsEditable) { $source.Control.AddHandler([System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent, [System.Windows.Controls.TextChangedEventHandler]$script:FormEvents.Dependency) } }
                'Check' { $source.Control.add_Checked($script:FormEvents.Dependency); $source.Control.add_Unchecked($script:FormEvents.Dependency) }
                default { if ($source.Control -is [System.Windows.Controls.TextBox]) { $source.Control.add_TextChanged($script:FormEvents.Dependency) } }
            }
        }
        $hasDependents = $true
    }
    if ($hasDependents) { Update-HTFormDependents -Controls $controls }
    foreach ($b in @((New-HTFormButtons -Buttons $ExtraButtons).Children)) {
        [void]$b.Parent.Children.Remove($b)
        [void]$w.FindName('dlgExtra').Children.Add($b)
    }
    $w.add_ContentRendered({
            param($s, $e)
            foreach ($c in $s.Tag.Controls.Values) {
                if ($c.Control -is [System.Windows.Controls.TextBox] -and $c.Control.IsVisible) { [void]$c.Control.Focus(); $c.Control.SelectAll(); break }
            }
        })
    if (@($Fields | Where-Object { $_.Type -eq 'Multiline' }).Count -gt 0) { $w.FindName('btnOk').IsDefault = $false }
    if (-not (Invoke-HTDialog $w)) { return $null }

    $result = [ordered]@{}
    foreach ($name in $controls.Keys) { $result[$name] = Get-HTFormControlValue -Entry $controls[$name] }
    Add-HTFormSummary -Controls $controls
    return $result
}

$script:FormSummaryLimit = 16

function Add-HTFormSummary {
    # Zapamiętuje wartości zatwierdzonego formularza dla potwierdzenia zmiany w tej samej akcji (Invoke-HTUiAction)
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Controls)
    $summary = $script:UI.FormSummary
    if ($null -eq $summary) { return }
    foreach ($entry in @($Controls.Values)) {
        if ($entry.Hidden) { continue }
        $line = ''
        try { $line = ConvertTo-HTFormSummaryLine -Field $entry.Field -Type $entry.Type -Value (Get-HTFormControlValue -Entry $entry) } catch { $line = '' }
        if ($line) { $summary.Add($line) }
    }
}

function Get-HTPendingFormSummary {
    # Ustawienia z formularzy zatwierdzonych w bieżącej akcji (najwyżej $script:FormSummaryLimit wierszy)
    $summary = $script:UI.FormSummary
    if ($null -eq $summary -or $summary.Count -eq 0) { return @() }
    $lines = @($summary.ToArray() | Select-Object -Unique)
    if ($lines.Count -le $script:FormSummaryLimit) { return $lines }
    return @($lines | Select-Object -First $script:FormSummaryLimit) + "… i $($lines.Count - $script:FormSummaryLimit) więcej ustawień"
}

function Update-HTFormDependents {
    # Widoczność pól zależnych (ShowWhen) według bieżących wartości pól źródłowych
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Controls)
    foreach ($entry in @($Controls.Values)) {
        if (-not $entry.ShowWhen) { continue }
        $value = Get-HTFormControlValue -Entry $entry.ShowWhen.Source
        $visible = $entry.ShowWhen.Values -contains [string]$value
        $entry.Hidden = -not $visible
        foreach ($element in @($entry.Elements)) { $element.Visibility = if ($visible) { 'Visible' } else { 'Collapsed' } }
    }
}

function Get-HTFormControlValue {
    param([Parameter(Mandatory)][hashtable]$Entry)
    $c = $Entry.Control
    switch ($Entry.Type) {
        'Combo' { if ($c.IsEditable) { return ([string]$c.Text).Trim() } else { return [string]$c.SelectedItem } }
        'Check' { return ($c.IsChecked -eq $true) }
        'Password' { return $c.Password }
        'Number' { $n = 0; [void][int]::TryParse($c.Text.Trim(), [ref]$n); return $n }
        'Date' {
            $text = $c.Text.Trim()
            if (-not $text) { return $null }
            $d = [datetime]::MinValue
            $formats = [string[]]@('yyyy-MM-dd HH:mm', 'yyyy-MM-dd', 'yyyy-MM-dd H:mm')
            if ([datetime]::TryParseExact($text, $formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
            return $null
        }
        'Multiline' { return ([string]$c.Text).Trim() }
        default { return ([string]$c.Text).Trim() }
    }
}

function Show-HTChoiceDialog {
    # Wybór jednej z opcji. Choices: tablica tekstów lub @{ Key; Text; Description; Icon (kod glifu); Style = Danger / Create }
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][object[]]$Choices, [string]$Prompt = '', [string]$Icon = 'E8FD')
    $w = New-HTDialog -Title $Title -Subtitle $Prompt -Body '<StackPanel x:Name="chHost"/>' -Icon $Icon -Width 520
    $w.FindName('btnOk').Visibility = 'Collapsed'
    $hostPanel = $w.FindName('chHost')
    foreach ($choice in $Choices) {
        $c = if ($choice -is [string]) { @{ Key = $choice; Text = $choice } } else { $choice }
        $b = New-Object System.Windows.Controls.Button
        $b.HorizontalContentAlignment = 'Stretch'
        $b.Padding = '14,9'
        $b.Margin = '0,0,0,6'
        if ($c.Style -eq 'Danger') { $b.Style = Get-HTThemeResource 'DangerButton' }
        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition
        $c1.Width = [System.Windows.GridLength]::Auto
        [void]$grid.ColumnDefinitions.Add($c1)
        [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
        $glyph = New-HTGlyphBlock -Code $(if ($c.Icon) { $c.Icon } else { 'E76C' }) -Size 16 -Color $(if ($c.Style -eq 'Danger') { '#FF8A95' } elseif ($c.Style -eq 'Create') { '#5FD39A' } else { '#8CB0FF' })
        $glyph.Margin = '0,0,14,0'
        [void]$grid.Children.Add($glyph)
        $texts = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = [string]$c.Text
        $t1.FontWeight = 'SemiBold'
        $t1.TextWrapping = 'Wrap'
        [void]$texts.Children.Add($t1)
        if ($c.Description) {
            $t2 = New-Object System.Windows.Controls.TextBlock
            $t2.Text = [string]$c.Description
            $t2.Foreground = Get-HTBrush '#8791A5'
            $t2.FontSize = 12
            $t2.TextWrapping = 'Wrap'
            [void]$texts.Children.Add($t2)
        }
        [System.Windows.Controls.Grid]::SetColumn($texts, 1)
        [void]$grid.Children.Add($texts)
        $b.Content = $grid
        $b.Tag = $(if ($c.Key) { $c.Key } else { $c.Text })
        $b.add_Click({
                param($s, $e)
                $win = [System.Windows.Window]::GetWindow($s)
                $win.Tag.Choice = $s.Tag
                Close-HTDialog -Window $win -Ok $true
            })
        [void]$hostPanel.Children.Add($b)
    }
    if (-not (Invoke-HTDialog $w)) { return $null }
    return $w.Tag.Choice
}

function Show-HTTextDialog {
    param([string]$Title, [string]$Text, [string]$Subtitle = '')
    $body = '<TextBox x:Name="txText" Style="{StaticResource MultiText}" IsReadOnly="True" TextWrapping="NoWrap"/>'
    $w = New-HTDialog -Title $Title -Subtitle $Subtitle -Body $body -Icon 'E8A5' -OkText 'Zamknij' -NoCancel -Width 920 -Height 640 -Resizable
    $box = $w.FindName('txText')
    $box.Text = ($Text -replace "`r?`n", "`r`n")
    $copy = New-HTButton -Text 'Kopiuj' -Icon 'E8C8'
    $copy.add_Click({
            param($s, $e)
            $t = [System.Windows.Window]::GetWindow($s).FindName('txText').Text
            if ($t) { Set-HTClipboard $t; Show-HTToast 'Skopiowano do schowka.' 'ok' }
        })
    [void]$w.FindName('dlgExtra').Children.Add($copy)
    [void](Invoke-HTDialog $w)
}

function Show-HTSecretDialog {
    # Dane poufne (hasła, klucze) z przyciskami kopiowania. Items: @{ Label; Value }
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][object[]]$Items, [string]$Description = '')
    if (-not $Description) { $Description = 'Dane poufne - nie przekazuj ich niezabezpieczonym kanałem. Skopiowane hasło zniknie ze schowka po 60 sekundach.' }
    $w = New-HTDialog -Title $Title -Subtitle $Description -Body '<StackPanel x:Name="scHost"/>' -Tone 'warn' -Icon 'E72E' -OkText 'Zamknij' -NoCancel -Width 600
    $hostPanel = $w.FindName('scHost')
    $first = $true
    foreach ($item in $Items) {
        $lbl = New-HTDialogText -Text ([string]$item.Label) -Color '#8791A5' -Size 12
        $lbl.Margin = $(if ($first) { '0,0,0,5' } else { '0,12,0,5' })
        [void]$hostPanel.Children.Add($lbl)
        $dock = New-Object System.Windows.Controls.DockPanel
        $btn = New-HTButton -Icon 'E8C8' -ToolTip 'Kopiuj'
        $btn.Margin = '6,0,0,0'
        [System.Windows.Controls.DockPanel]::SetDock($btn, 'Right')
        [void]$dock.Children.Add($btn)
        $box = New-Object System.Windows.Controls.TextBox
        $box.IsReadOnly = $true
        $box.FontFamily = 'Consolas'
        $box.FontSize = 14
        $box.Text = [string]$item.Value
        [void]$dock.Children.Add($box)
        $btn.Tag = $box
        $btn.add_Click({
                param($s, $e)
                Set-HTClipboard -Text $s.Tag.Text -Secret
                Show-HTToast 'Skopiowano do schowka (zostanie wyczyszczony po 60 s).' 'ok'
            })
        [void]$hostPanel.Children.Add($dock)
        $first = $false
    }
    [void](Invoke-HTDialog $w)
}
#endregion

#region Tabele w oknach (wybór obiektów, podgląd danych)
function New-HTDataTable {
    # Tabela danych dla siatki: kolumny z definicji (Text, Property albo Expression), ukryte __i (indeks) i __search
    param([object[]]$Items, [object[]]$Columns)
    $table = New-Object System.Data.DataTable 'Dane'
    [void]$table.Columns.Add('__i', [int])
    [void]$table.Columns.Add('__search', [string])
    foreach ($c in $Columns) { if (-not $table.Columns.Contains($c.Text)) { [void]$table.Columns.Add($c.Text, [object]) } }
    $table.BeginLoadData()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $row = $table.NewRow()
        $row['__i'] = $i
        $sb = New-Object System.Text.StringBuilder
        foreach ($c in $Columns) {
            $raw = if ($c.Expression) { & $c.Expression $Items[$i] } else { Get-HTObjectValue $Items[$i] $c.Property }
            $v = ConvertTo-HTCellValue $raw
            $row[$c.Text] = $v
            if ($v -isnot [System.DBNull]) { [void]$sb.Append([string]$v).Append(' ') }
        }
        $row['__search'] = $sb.ToString().ToLowerInvariant()
        $table.Rows.Add($row)
    }
    $table.EndLoadData()
    # Przecinek: PowerShell rozwija DataTable na wiersze (DataRow) przy zwracaniu z funkcji - wtedy
    # [DataView]::new() dostawał tablicę wierszy i okna z listą (podgląd danych, wybór) kończyły się błędem «new»
    return , $table
}

function Get-HTDefaultColumns {
    param([object[]]$Items, [int]$Max = 12)
    $first = @($Items)[0]
    if ($null -eq $first) { return @() }
    if ($first -is [string]) { return @(@{ Text = 'Nazwa'; Property = '__value' }) }
    return @($first.PSObject.Properties | Select-Object -First $Max | ForEach-Object { @{ Text = $_.Name; Property = $_.Name } })
}

function Add-HTGridColumns {
    param($Grid, [object[]]$Columns)
    $Grid.Columns.Clear()
    foreach ($c in $Columns) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header = $c.Text
        $col.Binding = New-Object System.Windows.Data.Binding ('[' + $c.Text + ']')
        $col.SortMemberPath = $c.Text
        $col.MaxWidth = 520
        $col.MinWidth = 54
        if ($c.Width) { $col.Width = New-Object System.Windows.Controls.DataGridLength ([double]$c.Width) }
        $style = New-Object System.Windows.Style ([System.Windows.Controls.TextBlock])
        $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::TextTrimmingProperty, [System.Windows.TextTrimming]::CharacterEllipsis)))
        $col.ElementStyle = $style
        $Grid.Columns.Add($col)
    }
}

function Set-HTViewFilter {
    # Filtr tekstowy (słowo z minusem wyklucza) + dodatkowe warunki RowFilter (-Extra, np. filtry kolumn)
    param([System.Data.DataView]$View, [string]$Text, [string[]]$Extra = @())
    $terms = @("$Text".Trim().ToLowerInvariant() -split '\s+' | Where-Object { $_ })
    $parts = foreach ($t in $terms) {
        $lit = ConvertTo-HTLikeLiteral ($(if ($t.StartsWith('-') -and $t.Length -gt 1) { $t.Substring(1) } else { $t }))
        if ($t.StartsWith('-') -and $t.Length -gt 1) { "__search NOT LIKE '*$lit*'" } else { "__search LIKE '*$lit*'" }
    }
    $parts = @($parts) + @($Extra | Where-Object { $_ })
    try { $View.RowFilter = (@($parts) -join ' AND ') } catch { $View.RowFilter = '' }
}

function ConvertTo-HTLikeLiteral {
    # Tekst do wzorca LIKE w filtrze DataView: znaki specjalne w nawiasach kwadratowych
    param([string]$Text)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        switch ($ch) {
            '[' { [void]$sb.Append('[[]') }
            ']' { [void]$sb.Append('[]]') }
            '*' { [void]$sb.Append('[*]') }
            '%' { [void]$sb.Append('[%]') }
            "'" { [void]$sb.Append("''") }
            default { [void]$sb.Append($ch) }
        }
    }
    return $sb.ToString()
}

$script:GridDialogXaml = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Grid.RowDefinitions>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="*"/>
  </Grid.RowDefinitions>
  <Grid Margin="0,0,0,8">
    <TextBox x:Name="gdSearch" Tag="Szukaj… (słowo z minusem wyklucza)" Width="320" HorizontalAlignment="Left"/>
    <Border Style="{StaticResource Chip}" HorizontalAlignment="Right">
      <TextBlock x:Name="gdCount" Foreground="#AEB6C4" FontSize="11.5"/>
    </Border>
  </Grid>
  <Border Grid.Row="1" Style="{StaticResource Card}" Padding="0">
    <DataGrid x:Name="gdGrid" Style="{StaticResource DarkGrid}" AutoGenerateColumns="False" Margin="1"/>
  </Border>
</Grid>
'@

$script:GridDialogEvents = @{
    Search = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        $view = $w.Tag.View
        Set-HTViewFilter -View $view -Text $s.Text
        $w.FindName('gdCount').Text = if ($view.Count -eq $view.Table.Rows.Count) { [string]$view.Count } else { "$($view.Count) z $($view.Table.Rows.Count)" }
    }
}

function New-HTGridDialog {
    param([string]$Title, [string]$Subtitle, [object[]]$Items, [object[]]$Columns, [string]$Icon, [string]$OkText, [switch]$NoCancel, [switch]$Multi)
    $w = New-HTDialog -Title $Title -Subtitle $Subtitle -Body $script:GridDialogXaml -Icon $Icon -OkText $OkText -NoCancel:$NoCancel -Width 960 -Height 640 -Resizable
    $table = New-HTDataTable -Items $Items -Columns $Columns
    $view = [System.Data.DataView]::new($table)
    $grid = $w.FindName('gdGrid')
    Add-HTGridColumns -Grid $grid -Columns $Columns
    $grid.SelectionMode = $(if ($Multi) { 'Extended' } else { 'Single' })
    $grid.ItemsSource = $view
    $w.Tag.View = $view
    $w.Tag.Items = $Items
    $w.Tag.Columns = $Columns
    $w.FindName('gdCount').Text = [string]$table.Rows.Count
    $w.FindName('gdSearch').add_TextChanged($script:GridDialogEvents.Search)
    $w.add_ContentRendered({ param($s, $e) [void]$s.FindName('gdSearch').Focus() })
    return $w
}

function Show-HTSelectionDialog {
    # Wybór obiektów z listy (wyszukiwanie, sortowanie). Zwraca wybrane obiekty albo $null.
    param(
        [Parameter(Mandatory)][string]$Title,
        [AllowEmptyCollection()][object[]]$Items,
        [object[]]$Columns,
        [string]$Prompt = '',
        [switch]$MultiSelect,
        [string]$OkText = 'Wybierz',
        [string]$Icon = 'E8B3'
    )
    $Items = @($Items | Where-Object { $null -ne $_ })
    if ($Items.Count -eq 0) {
        Show-HTMessage -Text 'Brak elementów do wyboru.' -Title $Title
        return $null
    }
    $isString = $Items[0] -is [string]
    if ($isString) {
        $Items = @($Items | ForEach-Object { [PSCustomObject]@{ Nazwa = $_ } })
        $Columns = @(@{ Text = 'Nazwa'; Property = 'Nazwa' })
    }
    if (-not $Columns) { $Columns = Get-HTDefaultColumns -Items $Items }
    $hint = if ($MultiSelect) { 'Ctrl / Shift - zaznaczanie wielu pozycji.' } else { 'Dwuklik wybiera pozycję.' }
    $w = New-HTGridDialog -Title $Title -Subtitle $(if ($Prompt) { "$Prompt  $hint" } else { $hint }) -Items $Items -Columns $Columns -Icon $Icon -OkText $OkText -Multi:$MultiSelect
    $w.Tag.Validate = {
        param($w)
        if ($w.FindName('gdGrid').SelectedItems.Count -eq 0) { Show-HTWarning 'Zaznacz co najmniej jedną pozycję.'; return $false }
        return $true
    }
    if (-not $MultiSelect) {
        $w.FindName('gdGrid').add_MouseDoubleClick({
                param($s, $e)
                if ($s.SelectedItems.Count -gt 0) { Close-HTDialog -Window ([System.Windows.Window]::GetWindow($s)) -Ok $true }
            })
    }
    if (-not (Invoke-HTDialog $w)) { return $null }
    $selected = foreach ($drv in @($w.FindName('gdGrid').SelectedItems)) { $Items[[int]$drv.Row['__i']] }
    if ($isString) { return @($selected | ForEach-Object { $_.Nazwa }) }
    return @($selected)
}

function Show-HTDataViewer {
    # Podgląd danych tabelarycznych z wyszukiwaniem, kopiowaniem i eksportem CSV
    param(
        [Parameter(Mandatory)][string]$Title,
        [AllowEmptyCollection()][AllowNull()][object[]]$Data,
        [object[]]$Columns,
        [string]$Description = '',
        [string]$ExportName = 'eksport',
        [string]$Icon = 'E8A5'
    )
    $Data = @($Data | Where-Object { $null -ne $_ })
    if ($Data.Count -eq 0) {
        Show-HTMessage -Text 'Brak danych do wyświetlenia.' -Title $Title
        return
    }
    if (-not $Columns) { $Columns = Get-HTDefaultColumns -Items $Data -Max 30 }
    $w = New-HTGridDialog -Title $Title -Subtitle $Description -Items $Data -Columns $Columns -Icon $Icon -OkText 'Zamknij' -NoCancel -Multi
    $w.Tag.ExportName = $ExportName
    $copy = New-HTButton -Text 'Kopiuj' -Icon 'E8C8' -ToolTip 'Kopiuj zaznaczone wiersze (lub wszystkie) w formacie Excel'
    $copy.Margin = '0,0,8,0'
    $copy.add_Click({
            param($s, $e)
            $win = [System.Windows.Window]::GetWindow($s)
            $grid = $win.FindName('gdGrid')
            $rows = if ($grid.SelectedItems.Count -gt 0) { @($grid.SelectedItems) } else { @($win.Tag.View) }
            $lines = @(($win.Tag.Columns | ForEach-Object { $_.Text }) -join "`t")
            foreach ($drv in $rows) { $lines += (($win.Tag.Columns | ForEach-Object { ([string](Get-HTObjectValue $drv $_.Text)) -replace "[`t`r`n]+", ' ' }) -join "`t") }
            Set-HTClipboard ($lines -join "`r`n")
            Show-HTToast "Skopiowano wierszy: $($rows.Count)." 'ok'
        })
    $export = New-HTButton -Text 'Eksport CSV' -Icon 'EDE1'
    $export.add_Click({
            param($s, $e)
            $win = [System.Windows.Window]::GetWindow($s)
            $rows = foreach ($drv in @($win.Tag.View)) {
                $o = [ordered]@{}
                foreach ($c in $win.Tag.Columns) { $v = Get-HTObjectValue $drv $c.Text; $o[$c.Text] = if ($null -eq $v) { '' } else { [string]$v } }
                [PSCustomObject]$o
            }
            Save-ContentToFile -Data @($rows) -Format 'csv' -Title 'Eksport danych' -DefaultName $win.Tag.ExportName | Out-Null
        })
    [void]$w.FindName('dlgExtra').Children.Add($copy)
    [void]$w.FindName('dlgExtra').Children.Add($export)
    [void](Invoke-HTDialog $w)
}
#endregion

#region Toasty, schowek
$script:ToastTimers = New-Object 'System.Collections.Generic.Dictionary[object,object]'
$script:Clipboard = @{ Secret = $null; Timer = $null }

function Show-HTToast {
    # Krótkie powiadomienie w prawym dolnym rogu okna (znika samo)
    param([Parameter(Mandatory)][string]$Text, [ValidateSet('info', 'ok', 'warn', 'crit')][string]$Tone = 'info', [int]$Seconds = 5)
    if ($null -ne $script:UI.DialogCapture) { $script:UI.DialogCapture.Add([PSCustomObject]@{ Title = 'Powiadomienie'; Text = $Text; Tone = $(if ($Tone -eq 'crit') { 'crit' } else { "toast-$Tone" }) }); return }
    $toastHost = $script:UI.Controls['toastHost']
    if (-not $toastHost) { return }
    try {
        $toneDef = $script:DialogTones[$Tone]
        # Większe powiadomienie: kolorowy pasek z lewej, ikona w kółku w kolorze komunikatu, większa czcionka
        $xaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Background="#1E2530" BorderBrush="#3A4454" BorderThickness="1"
        CornerRadius="10" Margin="0,10,0,0" MinWidth="340" MaxWidth="560" HorizontalAlignment="Right">
  <Border.Effect><DropShadowEffect BlurRadius="26" ShadowDepth="4" Opacity="0.6" Color="Black"/></Border.Effect>
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="5"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <Border Name="accent" CornerRadius="10,0,0,10"/>
    <Grid Grid.Column="1" Margin="16,14,20,14">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border Name="badge" Width="34" Height="34" CornerRadius="17" VerticalAlignment="Center" Margin="0,0,14,0">
        <TextBlock Name="icon" Style="{StaticResource Glyph}" FontSize="17" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <TextBlock Name="text" Grid.Column="1" TextWrapping="Wrap" FontSize="14.5" LineHeight="20" Foreground="#F2F4F8" VerticalAlignment="Center"/>
    </Grid>
  </Grid>
</Border>
'@
        $toast = New-HTUiElement $xaml
        $icon = $toast.FindName('icon')
        $icon.Text = Get-HTGlyph $toneDef.Icon
        $icon.Foreground = Get-HTBrush $toneDef.Fore
        $toast.FindName('badge').Background = Get-HTBrush $toneDef.Back
        $toast.FindName('accent').Background = Get-HTBrush $toneDef.Fore
        $toast.FindName('text').Text = $Text
        # Płynne pojawienie się (przesunięcie i przezroczystość)
        $toast.Opacity = 0
        $shift = New-Object System.Windows.Media.TranslateTransform 24, 0
        $toast.RenderTransform = $shift
        $duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(220))
        $toast.BeginAnimation([System.Windows.UIElement]::OpacityProperty, [System.Windows.Media.Animation.DoubleAnimation]::new(0, 1, $duration))
        $shift.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, [System.Windows.Media.Animation.DoubleAnimation]::new(24, 0, $duration))
        while ($toastHost.Children.Count -ge 4) { $toastHost.Children.RemoveAt(0) }
        [void]$toastHost.Children.Add($toast)
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds([Math]::Max(2, $Seconds))
        $script:ToastTimers[$timer] = $toast
        $timer.add_Tick({
                param($s, $e)
                $s.Stop()
                $t = $null
                if ($script:ToastTimers.TryGetValue($s, [ref]$t)) {
                    [void]$script:ToastTimers.Remove($s)
                    $h = $script:UI.Controls['toastHost']
                    if ($h -and $h.Children.Contains($t)) { $h.Children.Remove($t) }
                }
            })
        $timer.Start()
    }
    catch { Write-Verbose "Toast: $_" }
}

function Set-HTClipboard {
    # Kopiuje tekst do schowka. -Secret: wartość poufna - schowek jest czyszczony po 60 s (jeśli nadal ją zawiera)
    param([AllowEmptyString()][AllowNull()][string]$Text, [switch]$Secret)
    if ([string]::IsNullOrEmpty($Text)) {
        Write-Log -Message 'Brak treści do skopiowania.' -Type 'Warn'
        return
    }
    for ($i = 0; $i -lt 3; $i++) {
        try { [System.Windows.Clipboard]::SetText($Text); break }
        catch { Start-Sleep -Milliseconds 80 }
    }
    if (-not $Secret) { return }
    $script:Clipboard.Secret = $Text
    if (-not $script:Clipboard.Timer) {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromSeconds(60)
        $t.add_Tick({
                param($s, $e)
                $s.Stop()
                try {
                    if ($script:Clipboard.Secret -and [System.Windows.Clipboard]::ContainsText() -and [System.Windows.Clipboard]::GetText() -eq $script:Clipboard.Secret) {
                        [System.Windows.Clipboard]::Clear()
                    }
                }
                catch { Write-Verbose "Schowek: $_" }
                $script:Clipboard.Secret = $null
            })
        $script:Clipboard.Timer = $t
    }
    $script:Clipboard.Timer.Stop()
    $script:Clipboard.Timer.Start()
}
#endregion

#region Dziennik operacji (panel na dole okna)
function Add-HTLogItem {
    # Odbiorca wpisów Write-Log: lista w panelu dziennika, licznik nieprzeczytanych ostrzeżeń i powiadomienia
    param([Parameter(Mandatory)][object]$Entry)
    try {
        $items = $script:UI.LogItems
        if ($items.Count -ge 3000) { for ($i = 0; $i -lt 500; $i++) { $items.RemoveAt(0) } }
        $level = switch ($Entry.Type) { 'Warn' { 'WARN' } 'Error' { 'ERROR' } 'Debug' { 'DEBUG' } default { if ($Entry.Notify) { 'OK' } else { 'INFO' } } }
        $message = ($Entry.Message -replace '^(ℹ️|⚠️|❌|🔧)\s*', '')
        $item = [PSCustomObject]@{
            Time    = $Entry.Time.ToString('HH:mm:ss')
            Level   = $level
            Module  = $(if ($script:UI.ActiveModule) { [string]$script:UI.ActiveModule.Title } else { '' })
            Message = $message
        }
        $items.Add($item)
        if ($script:LogFilter.Levels.Count -gt 0 -or $script:LogFilter.Text) { Update-HTLogCount }
        $list = $script:UI.Controls['logList']
        if ($list -and $list.IsVisible) { $list.ScrollIntoView($item) }
        if (-not $script:UI.LogVisible -and ($level -eq 'WARN' -or $level -eq 'ERROR')) {
            $script:UI.LogUnread++
            Update-HTLogBadge
        }
        if ($Entry.Notify) {
            $tone = switch ($level) { 'WARN' { 'warn' } 'ERROR' { 'crit' } default { 'ok' } }
            Show-HTToast -Text $message -Tone $tone
        }
    }
    catch { Write-Verbose "Dziennik: $_" }
}

function Update-HTLogBadge {
    $badge = $script:UI.Controls['logBadge']
    if (-not $badge) { return }
    if ($script:UI.LogUnread -gt 0) {
        $script:UI.Controls['logBadgeText'].Text = [string][Math]::Min(99, $script:UI.LogUnread)
        $badge.Visibility = 'Visible'
    }
    else { $badge.Visibility = 'Collapsed' }
}

function Set-HTLogVisible {
    param([bool]$Visible)
    $c = $script:UI.Controls
    if (-not $c['logPanel']) { return }
    $script:UI.LogVisible = $Visible
    if ($Visible) {
        $c.logPanel.Visibility = 'Visible'
        $c.logSplitter.Visibility = 'Visible'
        $height = 200
        try { $height = [Math]::Min(800, [Math]::Max(100, [int](Get-HTUiState).LogHeight)) } catch { Write-Verbose $_ }
        $c.logRow.Height = New-Object System.Windows.GridLength $height
        $script:UI.LogUnread = 0
        Update-HTLogBadge
        if ($script:UI.LogItems.Count -gt 0) { $c.logList.ScrollIntoView($script:UI.LogItems[$script:UI.LogItems.Count - 1]) }
    }
    else {
        # Wysokość dziennika ustawiona przeciągnięciem - zapamiętana na kolejne otwarcia
        $actual = [int]$c.logRow.ActualHeight
        if ($c.logPanel.Visibility -eq 'Visible' -and $actual -ge 100) { try { Set-HTUiStateValue -Name 'LogHeight' -Value ([Math]::Min(800, $actual)) } catch { Write-Verbose $_ } }
        $c.logPanel.Visibility = 'Collapsed'
        $c.logSplitter.Visibility = 'Collapsed'
        $c.logRow.Height = New-Object System.Windows.GridLength 0
    }
}

# Filtr panelu dziennika: Levels - poziomy do pokazania (puste - wszystkie), Text - fragment komunikatu lub nazwy modułu
$script:LogFilter = @{ Levels = @(); Text = '' }
$script:LogFilterPredicate = {
    param($item)
    $f = $script:LogFilter
    if ($f.Levels.Count -gt 0 -and $f.Levels -notcontains [string]$item.Level) { return $false }
    if ($f.Text -and ([string]$item.Message).IndexOf($f.Text, [System.StringComparison]::CurrentCultureIgnoreCase) -lt 0 -and ([string]$item.Module).IndexOf($f.Text, [System.StringComparison]::CurrentCultureIgnoreCase) -lt 0) { return $false }
    return $true
}

function Set-HTLogFilter {
    param([string[]]$Levels = @(), [AllowEmptyString()][string]$Text = '')
    $script:LogFilter = @{ Levels = @($Levels | Where-Object { $_ }); Text = $Text.Trim() }
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($script:UI.LogItems)
    if ($script:LogFilter.Levels.Count -eq 0 -and -not $script:LogFilter.Text) { $view.Filter = $null }
    else { $view.Filter = [System.Predicate[object]]$script:LogFilterPredicate }
    Update-HTLogCount
}

function Update-HTLogCount {
    # Liczba widocznych wpisów przy aktywnym filtrze dziennika
    $label = $script:UI.Controls['logCount']
    if (-not $label) { return }
    $filtered = $script:LogFilter.Levels.Count -gt 0 -or $script:LogFilter.Text
    $list = $script:UI.Controls['logList']
    $label.Text = if ($filtered -and $list) { 'widoczne: {0} z {1}' -f $list.Items.Count, $script:UI.LogItems.Count } else { '' }
}
#endregion

#region Stan aplikacji: pasek stanu, zajętość, połączenia
function Set-HTStatus {
    param([AllowEmptyString()][string]$Text)
    $label = $script:UI.Controls['txtStatus']
    if ($label) { $label.Text = $Text }
}

function Set-HTBusy {
    # Tryb "zajęty": kursor, wskaźnik postępu, blokada przycisków modułu i połączeń
    param([bool]$Busy, [string]$Text)
    if ($Busy) {
        $script:UI.BusyDepth++
        if ($script:UI.BusyDepth -eq 1) { $script:UI.BusyStarted = [datetime]::Now }
    }
    else { $script:UI.BusyDepth = [Math]::Max(0, $script:UI.BusyDepth - 1) }
    $c = $script:UI.Controls
    if (-not $script:UI.Window) { return }
    $isBusy = $script:UI.BusyDepth -gt 0
    if ($Text) { Set-HTStatus -Text $Text }
    if ($c['statusDot']) { $c.statusDot.Fill = Get-HTBrush $(if ($isBusy) { '#4C7DF0' } else { '#5EE3AE' }) }
    if ($c['prgStatus']) {
        $c.prgStatus.IsIndeterminate = $isBusy
        $c.prgStatus.Visibility = if ($isBusy) { 'Visible' } else { 'Collapsed' }
    }
    $script:UI.Window.Cursor = if ($isBusy) { [System.Windows.Input.Cursors]::Wait } else { $null }
    if (($Busy -and $script:UI.BusyDepth -eq 1) -or -not $isBusy) { Set-ButtonsState -Action $(if ($isBusy) { 'Lock' } else { 'Unlock' }) }
    $m = $script:UI.ActiveModule
    if ($m -and $m.View_['busyChip']) {
        $m.View_.busyChip.Visibility = if ($isBusy) { 'Visible' } else { 'Collapsed' }
        if ($isBusy -and $Text) { $m.View_.busyText.Text = $Text }
    }
    Update-HTUi
    # Koniec długiej operacji, gdy pracujesz w innym programie: powiadomienie Windows i miganie paska zadań
    if (-not $isBusy -and $script:UI['BusyStarted']) {
        $elapsed = ([datetime]::Now - $script:UI.BusyStarted).TotalSeconds
        $script:UI.BusyStarted = $null
        $limit = [int]$Global:NotifyLongOperationsSeconds
        if ($limit -gt 0 -and $elapsed -ge $limit -and -not (Test-HTProgramActive)) {
            Show-HTWindowsNotification -Text $(if ($Text) { $Text } else { 'Operacja zakończona' }) -Seconds ([int]$elapsed)
        }
    }
}

function Set-HTProgress {
    param([int]$Value, [int]$Maximum, [string]$Text)
    $bar = $script:UI.Controls['prgStatus']
    if ($bar) {
        $bar.IsIndeterminate = $false
        $bar.Maximum = [Math]::Max(1, $Maximum)
        $bar.Value = [Math]::Min($bar.Maximum, [Math]::Max(0, $Value))
        $bar.Visibility = 'Visible'
    }
    if ($Text) {
        Set-HTStatus -Text $Text
        $m = $script:UI.ActiveModule
        if ($m -and $m.View_['busyText']) { $m.View_.busyText.Text = $Text }
    }
    Update-HTUi
}

function Set-ButtonsState {
    # Blokada przycisków akcji aktywnego modułu i przycisków połączeń na czas operacji
    param([Parameter(Mandatory)][ValidateSet("Lock", "Unlock")][string]$Action)
    $enabled = ($Action -eq 'Unlock')
    foreach ($b in $script:UI.ConnectButtons.Values) { if ($b) { $b.IsEnabled = $enabled } }
    foreach ($m in $script:UI.Modules.Values) {
        foreach ($b in @($m.Buttons)) { $b.IsEnabled = $enabled }
    }
    foreach ($p in $script:UI.Panels.Values) {
        foreach ($b in @($p.Buttons)) { $b.IsEnabled = $enabled }
    }
}

function Invoke-HTAction {
    # Wykonuje akcję z obsługą błędów, dziennikiem i wskaźnikiem zajętości; zwraca wynik akcji
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string[]]$RequiredService,
        [switch]$NoBusy
    )
    foreach ($service in $RequiredService) {
        if (-not (Assert-HTConnection -Service $service)) { return }
    }
    if (-not $NoBusy) { Set-HTBusy -Busy $true -Text "$Name…" }
    try {
        & $ScriptBlock
    }
    catch {
        $message = $_.Exception.Message
        Write-Log -Message "$Name - błąd: $message" -Type "Error"
        if (-not $NoBusy) { Set-HTBusy -Busy $false -Text "Błąd: $Name" }
        $NoBusy = $true
        Show-HTError -Text $Name -ErrorObject $message
    }
    finally {
        if (-not $NoBusy) { Set-HTBusy -Busy $false -Text 'Gotowe' }
    }
}

function Invoke-HTForEach {
    # Wykonuje operację dla wielu elementów i zbiera błędy; zwraca liczbę udanych operacji
    param (
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][scriptblock]$Describe
    )
    $errors = @()
    $ok = 0
    foreach ($item in $Items) {
        try {
            & $Action $item | Out-Null
            $ok++
        }
        catch {
            $errors += "$(& $Describe $item): $($_.Exception.Message)"
        }
    }
    if ($errors.Count -gt 0) {
        Write-Log -Message "Część operacji zakończyła się błędem: $($errors -join ' | ')" -Type "Warn"
        Show-HTWarning -Text "Wykonano: $ok, błędy: $($errors.Count)`n`n$($errors -join "`n")" -Title 'Wynik operacji'
    }
    return $ok
}

function Test-HTConnection {
    param ([ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string]$Service)
    switch ($Service) {
        "Exchange" { return [bool]$Global:ConnectedToExchange }
        "Graph" { return [bool]$Global:ConnectedToGraphAPI }
        "SharePoint" { return [bool]$Global:ConnectedToSharepointPnP }
        "AD" { return [bool]$Global:IsModuleActiveDirectoryLoaded }
    }
}

function Assert-HTConnection {
    param ([ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string]$Service)
    if (Test-HTConnection -Service $Service) { return $true }
    $message = switch ($Service) {
        "Exchange" { "Ta operacja wymaga połączenia z Exchange Online.`nKliknij 'Exchange' w prawym górnym rogu okna." }
        "Graph" { "Ta operacja wymaga połączenia z Microsoft Graph.`nKliknij 'Microsoft 365' w prawym górnym rogu okna." }
        "SharePoint" { "Ta operacja wymaga połączenia z witryną SharePoint (PnP).`nKliknij 'SharePoint' w prawym górnym rogu okna." }
        "AD" { "Moduł ActiveDirectory (RSAT) nie jest dostępny na tym komputerze." }
    }
    Write-Log -Message "Brak połączenia: $Service" -Type "Warn"
    Show-HTWarning -Text $message -Title 'Brak połączenia'
    return $false
}

function Update-ConnectionButtonText {
    # Stan połączenia w nagłówku (kropka + nazwa tenantu) i podpowiedź przycisku
    param ([ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string]$Service, [string]$TenantName = $null)
    $c = $script:UI.Controls
    $dot = $c["dot$Service"]
    $sub = $c["sub$Service"]
    $button = $script:UI.ConnectButtons[$Service]
    $names = @{ Exchange = 'Exchange Online'; Graph = 'Microsoft 365 (Graph)'; SharePoint = 'SharePoint (PnP)'; AD = 'Active Directory' }
    # Nazwa połączenia (tenant, witryna SharePoint) - zakres sprawdzeń w podsumowaniu do zgłoszenia
    if (-not $script:UI['ConnectionNames']) { $script:UI['ConnectionNames'] = @{} }
    $script:UI.ConnectionNames[$Service] = [string]$TenantName
    if ($dot) { $dot.Fill = Get-HTBrush $(if ($TenantName) { $script:DotColors.ok } else { $script:DotColors.off }) }
    if ($sub) {
        $sub.Text = if ($TenantName) { $TenantName } else { 'niepołączono' }
        $sub.Foreground = Get-HTBrush $(if ($TenantName) { '#8791A5' } else { '#5E6779' })
    }
    if ($button) {
        $button.ToolTip = if ($TenantName) { "$($names[$Service]): połączono ($TenantName). Kliknij, aby rozłączyć." } else { "$($names[$Service]): kliknij, aby połączyć." }
    }
    # Nazwa tenantu zmienia szerokość nagłówka - ponowne dopasowanie układu
    $script:UI.HeaderWidths = $null
    if ($script:UI['HeaderChanged']) { try { & $script:UI.HeaderChanged } catch { Write-Verbose "Nagłówek: $_" } }
}

#endregion

#region Logowanie interaktywne w przeglądarce (z możliwością anulowania)
<#
    Logowanie do usług Microsoft odbywa się w karcie domyślnej przeglądarki (MSAL nasłuchuje na localhost
    na odpowiedź z karty). Wywołanie Connect-* blokuje wątek okna, dlatego na czas logowania w osobnym wątku
    działa małe okno «Trwa logowanie» z przyciskiem «Anuluj» i limitem czasu. Anulowanie wysyła do oczekującego
    nasłuchu MSAL odpowiedź z błędem access_denied - Connect-* kończy się błędem zamiast czekać w nieskończoność
    (np. gdy karta przeglądarki została przypadkiem zamknięta). MSAL nasłuchuje przez HttpListener, czyli usługę
    http.sys - port należy wtedy do procesu System (PID 4), nie do programu. Gdy anulowanie nie zadziała, okno
    pozwala spróbować ponownie albo zamknąć program (wątek okna jest zablokowany i nie da się go inaczej odzyskać).
#>
$script:LoginWatchdogScript = {
    param($State)
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Helpdesk Tools - logowanie"
        Width="460" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Topmost="True"
        Background="#12171D" Foreground="#E4E8EF" FontFamily="Segoe UI" FontSize="13" UseLayoutRounding="True">
  <Border Padding="22,20,22,18">
    <StackPanel>
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
        <Border Width="38" Height="38" CornerRadius="10" Background="#1A2640" VerticalAlignment="Top">
          <TextBlock FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Text="&#xE774;" FontSize="17" Foreground="#8CB0FF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <StackPanel Grid.Column="1" Margin="14,0,0,0" VerticalAlignment="Center">
          <TextBlock Name="title" FontSize="16" FontWeight="SemiBold" Foreground="White" TextWrapping="Wrap"/>
          <TextBlock Text="Dokończ logowanie w karcie przeglądarki." Foreground="#8791A5" Margin="0,3,0,0" TextWrapping="Wrap"/>
        </StackPanel>
      </Grid>
      <TextBlock Name="info" TextWrapping="Wrap" Foreground="#C9D0DC" Margin="0,16,0,0" LineHeight="19"
                 Text="Jeśli karta została zamknięta albo logowanie się nie udało, kliknij «Anuluj logowanie» i połącz się ponownie."/>
      <ProgressBar Name="bar" Height="6" Margin="0,16,0,0" IsIndeterminate="True" Foreground="#4C7DF0" Background="#262D39" BorderThickness="0"/>
      <TextBlock Name="time" Foreground="#5E6779" FontSize="12" Margin="0,6,0,0"/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
        <Button Name="kill" Content="Zamknij program" Padding="16,6" MinWidth="140" Margin="0,0,10,0" Visibility="Collapsed" Background="#262D39" Foreground="#E4E8EF" BorderBrush="#3A4252"
                ToolTip="Kończy program - logowanie zablokowało okno programu. Po zamknięciu uruchom program ponownie."/>
        <Button Name="cancel" Content="Anuluj logowanie" Padding="16,6" MinWidth="140" Background="#3A1F25" Foreground="#FF8A95" BorderBrush="#5A2A33"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
"@
    $w = [System.Windows.Markup.XamlReader]::Parse($xaml)
    $w.FindName('title').Text = "Logowanie: $($State.Title)"
    $State.Window = $w
    $State.Dispatcher = $w.Dispatcher
    $started = Get-Date

    $cancelButton = $w.FindName('cancel')
    $killButton = $w.FindName('kill')
    $info = $w.FindName('info')

    # Nowe porty nasłuchu od początku logowania: programu albo http.sys (PID 4), na pętli zwrotnej lub wszystkich adresach
    $findPorts = {
        try {
            return @(Get-NetTCPConnection -OwningProcess @($State.ProcessId, 4) -State Listen -ErrorAction Stop |
                    Where-Object { $_.LocalAddress -in '127.0.0.1', '::1', '0.0.0.0', '::' -and $State.BasePorts -notcontains [int]$_.LocalPort } |
                    ForEach-Object { [int]$_.LocalPort } | Select-Object -Unique)
        }
        catch { return @() }
    }

    # Anulowanie nie przerwało logowania - ponowna próba albo zamknięcie programu
    $showEscape = {
        $State.EscapeShown = $true
        $info.Text = if ($State.CancelSent -gt 0) {
            'Program wysłał anulowanie, ale logowanie nadal trwa. Spróbuj ponownie albo zamknij program i uruchom go jeszcze raz (okno programu jest zablokowane do końca logowania).'
        }
        else {
            'Program nie czeka już na odpowiedź przeglądarki (karta logowania jest zakończona - np. «You are signed in» - albo nie została otwarta), a moduł nadal nie zakończył łączenia. Jeśli karta logowania jest otwarta - dokończ logowanie. Jeśli przeglądarka pokazuje, że zalogowano, a program dalej czeka - zamknij program i uruchom go ponownie.'
        }
        $info.Text += "`n`nSprawdzono: $((Get-Date).ToString('HH:mm:ss')) (próba $($State.Attempts))."
        $cancelButton.Content = 'Sprawdź ponownie'
        $cancelButton.IsEnabled = $true
        $killButton.Visibility = 'Visible'
    }

    $sendCancel = {
        param([string]$Reason)
        if ($State.Sending) { return }
        $State.Sending = $true
        $State.Attempts = [int]$State.Attempts + 1
        try {
            $State.Cancelled = $true
            if (-not $State.Reason) { $State.Reason = $Reason }
            $State.EscapeShown = $false
            $cancelButton.IsEnabled = $false
            $info.Text = 'Anulowanie logowania…'
            $sent = 0
            foreach ($port in @(& $findPorts)) {
                # Najpierw «localhost» - http.sys odrzuca żądanie z inną nazwą hosta niż zarejestrowana przez MSAL (400)
                foreach ($hostName in 'localhost', '127.0.0.1') {
                    try {
                        Invoke-WebRequest -Uri "http://$($hostName):$port/?error=access_denied&error_description=Login+cancelled+in+Helpdesk+Tools" -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop | Out-Null
                        $sent++
                        break
                    }
                    catch { Write-Verbose "Port $($port) ($hostName): $($_.Exception.Message)" }
                }
            }
            $State.CancelSent += $sent
            $State.CancelAt = Get-Date
            if ($sent -eq 0) { & $showEscape }
            else { $info.Text = 'Wysłano anulowanie - czekam na zakończenie logowania…' }
        }
        finally { $State.Sending = $false }
    }

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.add_Tick({
            if ($State.Done) { $timer.Stop(); $State.Closing = $true; $w.Close(); return }
            $left = [int]($State.TimeoutSeconds - ((Get-Date) - $started).TotalSeconds)
            if ($left -le 0 -and -not $State.Cancelled) { & $sendCancel 'timeout' }
            # Anulowanie wysłane, a logowanie po 15 s nadal trwa - pokaż wyjście awaryjne
            if ($State.Cancelled -and -not $State.EscapeShown -and -not $State.Sending -and $State.CancelAt -and ((Get-Date) - $State.CancelAt).TotalSeconds -ge 15) { & $showEscape }
            $w.FindName('time').Text = if ($State.Cancelled) { '' } else { 'Automatyczne anulowanie za {0}:{1:00}' -f [Math]::Floor([Math]::Max(0, $left) / 60), ([Math]::Max(0, $left) % 60) }
        })
    $cancelButton.add_Click({ & $sendCancel 'user' })
    $killButton.add_Click({
            $answer = [System.Windows.MessageBox]::Show($w, "Zamknąć program?`n`nLogowanie zablokowało okno programu i nie da się go przerwać inaczej. Niezapisane wyniki zostaną utracone. Po zamknięciu uruchom program ponownie.", 'Helpdesk Tools', 'YesNo', 'Warning')
            if ("$answer" -ne 'Yes') { return }
            $State.Killed = $true
            try { [System.Diagnostics.Process]::GetProcessById([int]$State.ProcessId).Kill() } catch { $info.Text = "Nie udało się zamknąć programu: $($_.Exception.Message). Zamknij go w Menedżerze zadań." }
        })
    # Zamknięcie okienka (X) = anulowanie (albo ponowna próba) - inaczej nie byłoby jak przerwać oczekiwania
    $w.add_Closing({
            param($s, $e)
            if ($State.Done -or $State.Closing) { return }
            $e.Cancel = $true
            if (-not $State.Sending) { & $sendCancel 'user' }
        })
    $timer.Start()
    [void]$w.ShowDialog()
}

function Start-HTLoginWatchdog {
    param([string]$Title, [int]$TimeoutSeconds = 300)
    # Porty nasłuchu programu i http.sys (PID 4) sprzed logowania - nowy port po starcie logowania to nasłuch MSAL
    $base = @()
    try { $base = @(Get-NetTCPConnection -OwningProcess @($PID, 4) -State Listen -ErrorAction Stop | ForEach-Object { [int]$_.LocalPort } | Select-Object -Unique) } catch { $base = @() }
    $state = [hashtable]::Synchronized(@{
            Title = $Title; TimeoutSeconds = [Math]::Max(30, $TimeoutSeconds); ProcessId = $PID; BasePorts = $base
            Done = $false; Closing = $false; Cancelled = $false; Reason = ''; CancelSent = 0; CancelAt = $null; Sending = $false
            EscapeShown = $false; Killed = $false; Window = $null; Dispatcher = $null
        })
    try {
        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.ThreadOptions = 'ReuseThread'
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript($script:LoginWatchdogScript.ToString()).AddArgument($state)
        $state.Handle = $ps.BeginInvoke()
        $state.PowerShell = $ps
        $state.Runspace = $rs
    }
    catch { Write-Log -Message "Nie udało się otworzyć okna postępu logowania: $($_.Exception.Message)" -Type 'Warn' }
    return $state
}

function Stop-HTLoginWatchdog {
    param([hashtable]$State)
    if (-not $State) { return }
    $State.Done = $true
    try {
        if ($State.Handle) { [void]$State.Handle.AsyncWaitHandle.WaitOne(3000) }
        if ($State.PowerShell) { if (-not $State.Handle.IsCompleted) { $State.PowerShell.Stop() }; $State.PowerShell.Dispose() }
        if ($State.Runspace) { $State.Runspace.Dispose() }
    }
    catch { Write-Verbose "Okno logowania: $_" }
}

function Invoke-HTWithoutSyncContext {
    <#
        Wykonuje blok bez SynchronizationContext wątku okna (WPF). Polecenia modułów Microsoft 365 wywołujące kod
        asynchroniczny synchronicznie (.GetAwaiter().GetResult()) nie zakleszczają wtedy wątku okna - dalszy ciąg
        zadania wykonuje się w puli wątków zamiast czekać na zablokowany wątek okna.
    #>
    # Nietypowe nazwy zmiennych - bloki zdefiniowane w tym module widzą zmienne wywołującego (dynamiczny zasięg)
    param([Parameter(Mandatory, Position = 0)][scriptblock]$HTSyncBlock)
    $htSyncPrevious = [System.Threading.SynchronizationContext]::Current
    if ($null -eq $htSyncPrevious) { return (& $HTSyncBlock) }
    [System.Threading.SynchronizationContext]::SetSynchronizationContext($null)
    try { & $HTSyncBlock }
    finally { [System.Threading.SynchronizationContext]::SetSynchronizationContext($htSyncPrevious) }
}

function Invoke-HTInteractiveLogin {
    <#
        Wykonuje blok logowania (Connect-*) z oknem «Trwa logowanie» (Anuluj + limit czasu).
        Anulowanie lub przekroczenie czasu kończy się wyjątkiem OperationCanceledException.
    #>
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock, [string]$Title = 'Microsoft 365', [int]$TimeoutSeconds = 0)
    if ($TimeoutSeconds -le 0) { $TimeoutSeconds = if ($Global:LoginTimeoutMinutes -gt 0) { [int]$Global:LoginTimeoutMinutes * 60 } else { 300 } }
    Set-HTStatus -Text "Logowanie: $Title - dokończ logowanie w przeglądarce…"
    Update-HTUi
    $watch = Start-HTLoginWatchdog -Title $Title -TimeoutSeconds $TimeoutSeconds
    Write-HTDebug { "Logowanie $($Title): start, limit $TimeoutSeconds s, porty nasłuchu przed logowaniem (program i http.sys): $(@($watch.BasePorts).Count)" }
    $started = Get-Date
    try {
        # Bez kontekstu synchronizacji okna: moduły (np. PnP) czekają synchronicznie na kod asynchroniczny, którego
        # dalszy ciąg trafiłby do zablokowanego wątku okna - przeglądarka kończy logowanie, a program wisi (zakleszczenie)
        Invoke-HTWithoutSyncContext $ScriptBlock
        Write-HTDebug { "Logowanie $($Title): zakończone po $([int]((Get-Date) - $started).TotalSeconds) s" }
    }
    catch {
        Write-HTDebug { "Logowanie $($Title): błąd po $([int]((Get-Date) - $started).TotalSeconds) s - anulowano: $($watch.Cancelled) ($($watch.Reason)), wysłane anulowania: $($watch.CancelSent), $($_.Exception.GetType().Name): $($_.Exception.Message)" }
        if ($watch -and $watch.Cancelled) {
            $why = if ($watch.Reason -eq 'timeout') { "przekroczono czas logowania ($([int]($TimeoutSeconds / 60)) min)" } else { 'anulowano logowanie' }
            throw [System.OperationCanceledException]::new("Nie połączono z usługą $Title - $why.")
        }
        throw
    }
    finally {
        Stop-HTLoginWatchdog -State $watch
        # Przeglądarka przejęła fokus - przywróć okno programu na wierzch
        $w = $script:UI.Window
        if ($w -and $w.IsVisible) {
            if ($w.WindowState -eq 'Minimized') { $w.WindowState = 'Normal' }
            [void]$w.Activate()
            $w.Topmost = $true
            $w.Topmost = $false
            Update-HTUi
        }
    }
}
#endregion

#region Obsługa zdarzeń kontrolek modułów (wspólny dyspozytor)
# Akcja dostaje kontekst modułu ($m) i kontrolkę źródłową - niezależnie od miejsca, w którym została zdefiniowana.
$script:Handlers = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:Dispatchers = @{
    Click            = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'Click' }
    TextChanged      = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'TextChanged' }
    Checked          = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'Checked' }
    Unchecked        = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'Unchecked' }
    SelectionChanged = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'SelectionChanged' }
}

function Register-HTControlHandler {
    param($Control, [string]$EventName, [hashtable]$Module, [scriptblock]$Action)
    $entry = $null
    if (-not $script:Handlers.TryGetValue($Control, [ref]$entry)) {
        $entry = @{ Module = $Module }
        $script:Handlers[$Control] = $entry
    }
    $entry.Module = $Module
    $isNew = -not $entry.ContainsKey($EventName)
    $entry[$EventName] = $Action
    if ($isNew) { $Control."add_$EventName"($script:Dispatchers[$EventName]) }
}

function Invoke-HTControlHandler {
    param($Source, [string]$EventName)
    try {
        $entry = $null
        if (-not $script:Handlers.TryGetValue($Source, [ref]$entry)) { return }
        $action = $entry[$EventName]
        if ($action) { Invoke-HTUiAction -Module $entry.Module -Action $action -Source $Source }
    }
    catch {
        Write-Log -Message "Błąd obsługi zdarzenia: $($_.Exception.Message)" -Type 'Error'
    }
}

function Invoke-HTUiAction {
    param([hashtable]$Module, [scriptblock]$Action, $Source = $null)
    # Akcja najwyższego poziomu zbiera wartości zatwierdzonych formularzy - potwierdzenie zmiany pokazuje, co zostanie ustawione
    $outer = -not $script:UI.ActionDepth
    if ($outer) {
        $script:UI.FormSummary = New-Object System.Collections.Generic.List[string]
        $script:UI.CommandWarnings = New-Object System.Collections.Generic.List[string]
        $script:UI.TargetSource = ''
    }
    $script:UI.ActionDepth = [int]$script:UI.ActionDepth + 1
    try {
        # Bez kontekstu synchronizacji okna - polecenia Graph/Exchange/PnP nie zakleszczą wątku okna (Invoke-HTWithoutSyncContext).
        # Ostrzeżenia poleceń (np. Exchange: «Events from Email… deprecated») trafiają do dziennika zamiast tylko do konsoli.
        $null = Invoke-HTWithoutSyncContext {
            & $Action $Module $Source 3>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.WarningRecord] -and $null -ne $script:UI.CommandWarnings) { $script:UI.CommandWarnings.Add([string]$_.Message) }
            }
        }
    }
    catch {
        # Moduł zablokowany dla konta MFA (Show-HTModule) - wpis w dzienniku już jest, wystarczy powiadomienie
        if ($_.Exception -is [System.UnauthorizedAccessException] -and $_.Exception.Data['HTAccess']) { Show-HTToast $_.Exception.Message 'warn' 5; return }
        Write-Log -Message "Błąd: $($_.Exception.Message)" -Type 'Error'
        Write-HTDebug { "Stos błędu ($($_.Exception.GetType().FullName)):`n$($_.ScriptStackTrace)" }
        Show-HTError 'Operacja nie powiodła się.' $_
    }
    finally {
        $script:UI.ActionDepth = [Math]::Max(0, [int]$script:UI.ActionDepth - 1)
        if ($outer) {
            $script:UI.FormSummary = $null
            $warnings = $script:UI.CommandWarnings
            $script:UI.CommandWarnings = $null
            if ($warnings -and $warnings.Count) {
                $where = if ($Module -and $Module.Title) { [string]$Module.Title } else { 'polecenie' }
                foreach ($line in @(Group-HTWarningMessages -Messages $warnings.ToArray())) { Write-Log -Message "Ostrzeżenie ($where): $line" -Type 'Warn' }
            }
        }
    }
}
#endregion

#region Przestrzenie robocze i moduły
function Register-HTWorkspace {
    <#
        Przestrzeń robocza = przycisk na górnym pasku + lista obiektów po lewej (-Panel) + własna nawigacja modułów.
        -Panel: klucz panelu obiektów (New-HTTargetPanel) albo pusty (bez listy).
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Title,
        [string]$Icon = 'E80F',
        [string]$Panel = '',
        [string]$Description = '',
        [string[]]$Categories = @(),
        [string]$Service = ''
    )
    $script:UI.Workspaces[$Key] = @{
        Key = $Key; Title = $Title; Icon = $Icon; Panel = $Panel; Description = $Description; Categories = @($Categories)
        Service = $Service; NavHost = $null; Tab = $null; NavItems = @{}; LastModule = ''
    }
}

function Register-HTModule {
    <#
        Moduł = pozycja w nawigacji przestrzeni roboczej, w kategorii -Category.
        -Build { param($m) } buduje panel parametrów i przyciski akcji (przy pierwszym otwarciu).
        Kontrolki potrzebne w akcjach zapisuj w $m.C (np. $m.C.Days = Add-HTNumeric ...), bo akcje
        wykonują się później - lokalne zmienne bloku Build już wtedy nie istnieją.
    #>
    param(
        [Parameter(Mandatory)][string]$Workspace,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Title,
        [string]$Icon = 'E74C',
        [string]$Description = '',
        [string]$Service = '',
        [Parameter(Mandatory)][scriptblock]$Build
    )
    $definition = @{ Workspace = $Workspace; Category = $Category; Key = $Key; Title = $Title; Icon = $Icon; Description = $Description; Service = $Service; Build = $Build }
    for ($i = 0; $i -lt $script:UI.ModuleDefs.Count; $i++) {
        if ($script:UI.ModuleDefs[$i].Key -eq $Key) { $script:UI.ModuleDefs[$i] = $definition; return }
    }
    [void]$script:UI.ModuleDefs.Add($definition)
}

function Get-HTModuleDefinition([string]$Key) {
    foreach ($d in $script:UI.ModuleDefs) { if ($d.Key -eq $Key) { return $d } }
    return $null
}

$script:NavEvents = @{
    CategoryClick  = {
        param($s, $e)
        try {
            $collapsed = @($s.Tag.Items | Where-Object { $_.Visibility -eq 'Visible' }).Count -gt 0
            Set-HTNavCategoryState -Header $s -Collapsed $collapsed
        }
        catch { Write-Log -Message "Nawigacja: $($_.Exception.Message)" -Type 'Warn' }
    }
    WorkspaceClick = {
        param($s, $e)
        try { Show-HTWorkspace -Key ([string]$s.Tag) }
        catch { Write-Log -Message "Błąd przełączania przestrzeni: $($_.Exception.Message)" -Type 'Error' }
    }
    MenuOpening    = {
        param($s, $e)
        try {
            $key = [string]$s.Tag
            $menu = $s.ContextMenu
            $menu.Items.Clear()
            $fav = Test-HTFavoriteModule $key
            [void]$menu.Items.Add((New-HTMenuItem -Text $(if ($fav) { 'Usuń z ulubionych' } else { 'Dodaj do ulubionych' }) -Icon $(if ($fav) { 'E8D9' } else { 'E734' }) -Data $key -Action {
                        param($m, $src)
                        $k = [string]$src.Tag.Data
                        Set-HTFavoriteModule -Key $k -Favorite (-not (Test-HTFavoriteModule $k))
                        Update-HTNavFavorites
                    }))
            [void]$menu.Items.Add((New-HTMenuItem -Text 'Szukaj modułów (Ctrl+K)' -Icon 'E721' -Action { param($m) Show-HTCommandPalette }))
        }
        catch { Write-Verbose $_ }
    }
    ModuleClick    = {
        param($s, $e)
        try { Show-HTModule -Key ([string]$s.Tag) }
        catch {
            if ($_.Exception -is [System.UnauthorizedAccessException] -and $_.Exception.Data['HTAccess']) { Show-HTToast $_.Exception.Message 'warn' 5; return }
            Write-Log -Message "Błąd otwierania modułu: $($_.Exception.Message)" -Type 'Error'
            Show-HTError 'Nie można otworzyć modułu.' $_
        }
    }
}

function Initialize-HTNavigation {
    # Przyciski przestrzeni roboczych i nawigacja modułów (kategorie w kolejności rejestracji)
    $c = $script:UI.Controls
    $c.wsSwitcher.Children.Clear()
    $c.navHost.Children.Clear()
    $i = 0
    foreach ($ws in $script:UI.Workspaces.Values) {
        $i++
        $tab = New-Object System.Windows.Controls.RadioButton
        $tab.Style = Get-HTThemeResource 'WorkspaceTab'
        $tab.GroupName = 'workspaces'
        $tab.Content = New-HTIconContent -Text $ws.Title -Icon $ws.Icon
        $tab.Tag = $ws.Key
        $tab.ToolTip = "$($ws.Title): $($ws.Description) (Ctrl+$i)"
        $tab.add_Click($script:NavEvents.WorkspaceClick)
        [void]$c.wsSwitcher.Children.Add($tab)
        $ws.Tab = $tab

        $panel = New-Object System.Windows.Controls.StackPanel
        $panel.Visibility = 'Collapsed'
        $ws.NavHost = $panel
        $ws.NavItems = @{}
        [void]$c.navHost.Children.Add($panel)
        $defs = @($script:UI.ModuleDefs | Where-Object { $_.Workspace -eq $ws.Key })
        $categories = New-Object System.Collections.ArrayList
        foreach ($order in @($ws.Categories)) { if ($order -and @($defs | Where-Object { $_.Category -eq $order }).Count -gt 0) { [void]$categories.Add($order) } }
        foreach ($d in $defs) { if (-not $categories.Contains($d.Category)) { [void]$categories.Add($d.Category) } }
        foreach ($cat in $categories) {
            # Nagłówek kategorii zwija i rozwija jej moduły (stan zapamiętany w UiState.json)
            $collapseKey = "$($ws.Key)|$cat"
            $collapsed = Test-HTNavCategoryCollapsed $collapseKey
            $header = New-Object System.Windows.Controls.Grid
            $header.Background = [System.Windows.Media.Brushes]::Transparent
            $header.Cursor = [System.Windows.Input.Cursors]::Hand
            $header.ToolTip = 'Kliknij, aby zwinąć lub rozwinąć kategorię'
            [void]$header.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
            $chevronColumn = New-Object System.Windows.Controls.ColumnDefinition
            $chevronColumn.Width = [System.Windows.GridLength]::Auto
            [void]$header.ColumnDefinitions.Add($chevronColumn)
            $title = New-Object System.Windows.Controls.TextBlock
            $title.Style = Get-HTThemeResource 'NavHeader'
            $title.Text = $cat.ToUpperInvariant()
            [void]$header.Children.Add($title)
            $chevron = New-HTGlyphBlock -Code $(if ($collapsed) { 'E76C' } else { 'E70D' }) -Size 9 -Color '#5E6779'
            $chevron.Margin = '0,14,10,5'
            $chevron.VerticalAlignment = 'Center'
            [System.Windows.Controls.Grid]::SetColumn($chevron, 1)
            [void]$header.Children.Add($chevron)
            $items = New-Object System.Collections.Generic.List[object]
            $header.Tag = @{ Key = $collapseKey; Items = $items; Chevron = $chevron }
            $header.add_MouseLeftButtonUp($script:NavEvents.CategoryClick)
            [void]$panel.Children.Add($header)
            foreach ($d in @($defs | Where-Object { $_.Category -eq $cat })) {
                $item = New-HTNavItem -Definition $d -Workspace $ws.Key
                $ws.NavItems[$d.Key] = $item
                $item.Visibility = if ($collapsed) { 'Collapsed' } else { 'Visible' }
                $items.Add($item)
                $script:NavCategoryOf[$d.Key] = $header
                [void]$panel.Children.Add($item)
            }
        }
    }
}

function New-HTNavItem {
    param([hashtable]$Definition, [string]$Workspace)
    $rb = New-Object System.Windows.Controls.RadioButton
    $rb.Style = Get-HTThemeResource 'NavItem'
    $rb.GroupName = "nav_$Workspace"
    $rb.Tag = $Definition.Key
    if ($Definition.Description) { $rb.ToolTip = $Definition.Description }
    $grid = New-Object System.Windows.Controls.Grid
    foreach ($width in @('Auto', '*')) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = if ($width -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
        [void]$grid.ColumnDefinitions.Add($cd)
    }
    $icon = New-HTGlyphBlock -Code $Definition.Icon -Size 14
    $icon.Margin = '2,0,11,0'
    $icon.Width = 18
    [void]$grid.Children.Add($icon)
    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Definition.Title
    $text.TextTrimming = 'CharacterEllipsis'
    $text.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($text, 1)
    [void]$grid.Children.Add($text)
    # Gwiazdka ulubionych (prawy przycisk na pozycji - dodanie / usunięcie)
    $cd = New-Object System.Windows.Controls.ColumnDefinition
    $cd.Width = [System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($cd)
    $star = New-HTGlyphBlock -Code 'E735' -Size 10 -Color '#FFC46B'
    $star.Margin = '6,0,0,0'
    $star.Visibility = if (Test-HTFavoriteModule $Definition.Key) { 'Visible' } else { 'Collapsed' }
    [System.Windows.Controls.Grid]::SetColumn($star, 2)
    [void]$grid.Children.Add($star)
    $script:NavStars[$Definition.Key] = $star
    $rb.Content = $grid
    $rb.ContextMenu = New-Object System.Windows.Controls.ContextMenu
    $rb.add_ContextMenuOpening($script:NavEvents.MenuOpening)
    $rb.add_Click($script:NavEvents.ModuleClick)
    return $rb
}

$script:NavStars = @{}
# Moduł -> nagłówek jego kategorii (rozwinięcie kategorii przy przejściu do modułu z palety lub ulubionych)
$script:NavCategoryOf = @{}

function Set-HTNavCategoryState {
    param([Parameter(Mandatory)]$Header, [bool]$Collapsed)
    $tag = $Header.Tag
    foreach ($item in $tag.Items) { $item.Visibility = if ($Collapsed) { 'Collapsed' } else { 'Visible' } }
    $tag.Chevron.Text = Get-HTGlyph $(if ($Collapsed) { 'E76C' } else { 'E70D' })
    Set-HTNavCategoryCollapsed -Key $tag.Key -Collapsed $Collapsed
}

function Show-HTNavItem {
    # Rozwija zwiniętą kategorię, w której jest moduł
    param([string]$Key)
    $header = $script:NavCategoryOf[$Key]
    if ($header -and @($header.Tag.Items | Where-Object { $_.Visibility -ne 'Visible' }).Count) { Set-HTNavCategoryState -Header $header -Collapsed $false }
}

function Update-HTNavFavorites {
    foreach ($key in @($script:NavStars.Keys)) { $script:NavStars[$key].Visibility = if (Test-HTFavoriteModule $key) { 'Visible' } else { 'Collapsed' } }
}

function Show-HTWorkspace {
    param([string]$Key, [string]$ModuleKey = '')
    if (-not $script:UI.Workspaces.Contains($Key)) { $Key = @($script:UI.Workspaces.Keys)[0] }
    if (-not (Test-HTWorkspaceAllowed $Key)) {
        # Przestrzeń zablokowana dla konta MFA: pierwsza dostępna
        $Key = @($script:UI.Workspaces.Keys | Where-Object { Test-HTWorkspaceAllowed $_ })[0]
        $ModuleKey = ''
        if (-not $Key) {
            if ($script:UI.ActiveModule) { $script:UI.ActiveModule.Root.Visibility = 'Collapsed'; $script:UI.ActiveModule = $null }
            foreach ($other in $script:UI.Workspaces.Values) { if ($other.NavHost) { $other.NavHost.Visibility = 'Collapsed' } }
            $script:UI.ActiveWorkspace = $null
            return
        }
    }
    $ws = $script:UI.Workspaces[$Key]
    $previous = $script:UI.ActiveWorkspace
    $script:UI.ActiveWorkspace = $Key
    foreach ($other in $script:UI.Workspaces.Values) {
        if ($other.NavHost) { $other.NavHost.Visibility = if ($other.Key -eq $Key) { 'Visible' } else { 'Collapsed' } }
        if ($other.Tab -and $other.Key -eq $Key -and $other.Tab.IsChecked -ne $true) { $other.Tab.IsChecked = $true }
    }
    $c = $script:UI.Controls
    foreach ($p in $script:UI.Panels.Values) { $p.Root.Visibility = if ($p.Key -eq $ws.Panel) { 'Visible' } else { 'Collapsed' } }
    $c.targetColumn.Width = if ($ws.Panel) { New-Object System.Windows.GridLength 320 } else { New-Object System.Windows.GridLength 0 }
    $c.txtSubtitle.Text = $ws.Description
    if ($previous -and $previous -ne $Key) { Write-Log -Message "Przestrzeń robocza: $($ws.Title)" -Type 'Info' }
    if (-not $ModuleKey) { $ModuleKey = $ws.LastModule }
    if (-not $ModuleKey) { try { $ModuleKey = [string](Get-HTUiState).LastModules[$Key] } catch { $ModuleKey = '' } }
    $def = Get-HTModuleDefinition $ModuleKey
    if (-not $def -or $def.Workspace -ne $Key -or -not (Test-HTModuleAllowed $def.Key)) {
        $def = $null
        foreach ($d in $script:UI.ModuleDefs) { if ($d.Workspace -eq $Key -and (Test-HTModuleAllowed $d.Key)) { $def = $d; break } }
    }
    if ($def) { Show-HTModule -Key $def.Key }
    elseif ($script:UI.ActiveModule) { $script:UI.ActiveModule.Root.Visibility = 'Collapsed'; $script:UI.ActiveModule = $null }
    # Pierwsze otwarcie przestrzeni: pusta lista obiektów wczytuje się sama, gdy usługa jest dostępna
    $panel = if ($ws.Panel) { $script:UI.Panels[$ws.Panel] } else { $null }
    if ($panel -and $panel.Loader -and -not $panel.AutoTried -and $script:UI.BusyDepth -eq 0) {
        $empty = if ($panel.IsTree) { $panel.pTree.Items.Count -eq 0 } else { $panel.Table.Rows.Count -eq 0 }
        if ($empty -and (-not $panel.Service -or (Test-HTConnection -Service $panel.Service))) {
            $panel.AutoTried = $true
            Invoke-HTPanelLoad -Panel $panel -Quiet
        }
    }
}

function Show-HTModule {
    param([string]$Key)
    $definition = Get-HTModuleDefinition $Key
    if (-not $definition) { return }
    if (-not (Test-HTModuleAllowed $Key)) {
        # Moduł zablokowany dla konta MFA (Uprawnienia…) - wyjątek przerywa też akcje, które po otwarciu modułu
        # wypełniają jego pola albo uruchamiają jego operacje
        $text = 'Konto «{0}» nie ma dostępu do modułu «{1}».' -f (Get-HTAccess).Account, $definition.Title
        Write-Log -Message $text -Type 'Warn'
        $ex = New-Object System.UnauthorizedAccessException($text)
        $ex.Data['HTAccess'] = $true
        throw $ex
    }
    if ($script:UI.ActiveWorkspace -ne $definition.Workspace) { Show-HTWorkspace -Key $definition.Workspace -ModuleKey $Key; return }
    $m = $script:UI.Modules[$Key]
    if (-not $m) { $m = Initialize-HTModule -Definition $definition }
    $active = $script:UI.ActiveModule
    if ($active -and -not [object]::ReferenceEquals($active, $m)) { $active.Root.Visibility = 'Collapsed' }
    $m.Root.Visibility = 'Visible'
    $script:UI.ActiveModule = $m
    $ws = $script:UI.Workspaces[$definition.Workspace]
    $ws.LastModule = $Key
    try { Add-HTRecentModule -Key $Key -Workspace $definition.Workspace } catch { Write-Verbose $_ }
    $nav = $ws.NavItems[$Key]
    if ($nav -and $nav.IsChecked -ne $true) { $nav.IsChecked = $true }
    if ($nav -and $nav.Visibility -ne 'Visible') { Show-HTNavItem -Key $Key }
    if ($m.OnShow) { Invoke-HTUiAction -Module $m -Action $m.OnShow }
}

function New-HTModuleContext {
    param([hashtable]$Definition)
    $ws = $script:UI.Workspaces[$Definition.Workspace]
    return @{
        Key            = $Definition.Key
        Title          = $Definition.Title
        Description    = $Definition.Description
        Category       = $Definition.Category
        Icon           = $Definition.Icon
        Workspace      = $Definition.Workspace
        WorkspaceTitle = $(if ($ws) { $ws.Title } else { '' })
        Panel          = $(if ($ws) { $ws.Panel } else { '' })
        Service        = $(if ($Definition.Service) { $Definition.Service } elseif ($ws) { $ws.Service } else { '' })
        Buttons        = New-Object System.Collections.ArrayList
        PrimaryButton  = $null
        RowActions     = New-Object System.Collections.ArrayList
        RowDoubleClick = $null
        OnShow         = $null
        SecretColumns  = @()
        HiddenColumns  = @()
        ColorBools     = $false
        GoodWhenNo     = @()
        RevealSecrets  = $false
        Stats          = @{}
        EmptyText      = ''
        EmptyHint      = ''
        ResultHint     = ''
        C              = @{}
        Data           = @{}
        View_          = @{}
        ColumnIndex    = @{}
        Root           = $null
        ParamsCard     = $null
        ParamsStack    = $null
        StatsGrid      = $null
        Grid           = $null
        Table          = $null
        View           = $null
        FilterBox      = $null
        Objects        = New-Object System.Collections.ArrayList
        # Filtry kolumn (ColumnFilters.psm1), lejki w nagłówkach, kliknięta komórka menu, kolumny ukryte przez użytkownika
        ColumnFilters  = [ordered]@{}
        FilterButtons  = @{}
        MenuCell       = $null
        UserHidden     = (New-HTUserHiddenSet -Key $Definition.Key -Remember:([bool]$Definition.Workspace))
    }
}

function New-HTUserHiddenSet {
    # Kolumny ukryte przez użytkownika - zapamiętane między uruchomieniami dla modułów nawigacji
    param([string]$Key, [switch]$Remember)
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    if ($Remember -and $Key) { foreach ($c in @(Get-HTModuleHiddenColumns $Key)) { [void]$set.Add($c) } }
    return , $set
}

function Initialize-HTModule {
    param([hashtable]$Definition)
    $m = New-HTModuleContext -Definition $Definition
    $script:UI.Modules[$Definition.Key] = $m
    New-HTModuleView -Module $m
    try { $null = & $Definition.Build $m }
    catch {
        Write-Log -Message "Nie udało się zbudować modułu '$($m.Title)': $($_.Exception.Message)" -Type 'Error'
        Add-HTLabel -Parent (Add-HTToolbarRow -Module $m) -Text "Błąd modułu: $($_.Exception.Message)" | Out-Null
    }
    Complete-HTModuleView -Module $m
    $m.Root.Visibility = 'Collapsed'
    [void]$script:UI.Controls['contentHost'].Children.Add($m.Root)
    return $m
}

function Get-HTActiveModule { return $script:UI.ActiveModule }

function Get-HTModuleDefinitions { return @($script:UI.ModuleDefs) }

function Get-HTModuleInstance {
    # Moduł (zbudowany - bez pokazywania, gdy jeszcze nie był otwierany)
    param([Parameter(Mandatory)][string]$Key)
    $m = $script:UI.Modules[$Key]
    if (-not $m) { $d = Get-HTModuleDefinition $Key; if ($d) { $m = Initialize-HTModule -Definition $d } }
    return $m
}

function Get-HTWorkspaceTitle {
    param([string]$Key)
    $ws = $script:UI.Workspaces[$Key]
    if ($ws) { return [string]$ws.Title }
    return $Key
}
#endregion

#region Lista obiektów (lewy panel): zaznaczanie, wyszukiwanie, wczytywanie z listy
$script:TargetPanelXaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="#12171D" BorderBrush="#1E242E" BorderThickness="0,0,1,0">
  <Grid Margin="14,14,12,10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid Margin="2,0,0,10">
      <TextBlock x:Name="pTitle" Foreground="#8791A5" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center"/>
      <Border Style="{StaticResource Chip}" HorizontalAlignment="Right" Margin="0">
        <TextBlock x:Name="pCount" Text="0" Foreground="#AEB6C4" FontSize="11"/>
      </Border>
    </Grid>
    <Border Grid.Row="1" Style="{StaticResource Card}" Padding="12,12,12,6" Margin="0,0,0,10">
      <StackPanel x:Name="pSource"/>
    </Border>
    <TextBox x:Name="pSearch" Grid.Row="2" Margin="0,0,0,8"/>
    <Grid Grid.Row="3">
      <ListBox x:Name="pList" SelectionMode="Extended">
        <ListBox.ItemTemplate>
          <DataTemplate>
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <CheckBox IsChecked="{Binding [Sel], Mode=OneWay}" Margin="0,0,10,0" VerticalAlignment="Center" Focusable="False"/>
              <Ellipse Grid.Column="1" Width="8" Height="8" Fill="{Binding [Dot]}" Margin="0,0,10,0" VerticalAlignment="Center"/>
              <StackPanel Grid.Column="2">
                <TextBlock Text="{Binding [Title]}" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                <TextBlock Text="{Binding [Sub]}" Foreground="#7B8496" FontSize="11.5" TextTrimming="CharacterEllipsis"/>
              </StackPanel>
            </Grid>
          </DataTemplate>
        </ListBox.ItemTemplate>
      </ListBox>
      <TreeView x:Name="pTree" Visibility="Collapsed" BorderThickness="0" Background="Transparent" Padding="0"/>
      <StackPanel x:Name="pEmpty" HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False" Margin="10">
        <TextBlock x:Name="pEmptyIcon" Style="{StaticResource Glyph}" FontSize="28" Foreground="#3A4352" HorizontalAlignment="Center"/>
        <TextBlock x:Name="pEmptyText" Foreground="#5E6779" TextAlignment="Center" TextWrapping="Wrap" Margin="0,10,0,0"/>
      </StackPanel>
    </Grid>
    <Grid Grid.Row="4" Margin="0,8,0,0">
      <StackPanel x:Name="pSelButtons" Orientation="Horizontal">
        <Button x:Name="pAll" Style="{StaticResource GhostButton}" ToolTip="Zaznacz widoczne"/>
        <Button x:Name="pNone" Style="{StaticResource GhostButton}" ToolTip="Odznacz wszystkie"/>
        <Button x:Name="pInvert" Style="{StaticResource GhostButton}" ToolTip="Odwróć zaznaczenie widocznych"/>
        <Button x:Name="pPaste" Style="{StaticResource GhostButton}" ToolTip="Zaznacz obiekty z listy (wklej lub wczytaj z pliku CSV/TXT)"/>
      </StackPanel>
      <TextBlock x:Name="pSel" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#8791A5" FontSize="12"/>
    </Grid>
  </Grid>
</Border>
'@

$script:TargetPanels = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:TargetEvents = @{
    ItemClick     = {
        param($s, $e)
        try {
            $cb = $e.OriginalSource
            if (-not ($cb -is [System.Windows.Controls.CheckBox])) { return }
            $drv = $cb.DataContext
            if (-not ($drv -is [System.Data.DataRowView])) { return }
            $p = $script:TargetPanels[$s]
            $value = ($cb.IsChecked -eq $true)
            # Kliknięcie pola w jednym z kilku zaznaczonych wierszy zmienia je wszystkie
            $rows = @($s.SelectedItems | Where-Object { $_ -is [System.Data.DataRowView] })
            if ($rows.Count -gt 1 -and $rows -contains $drv) { foreach ($r in $rows) { $r.Row['Sel'] = $value } }
            else { $drv.Row['Sel'] = $value }
            Update-HTTargetCount $p
        }
        catch { Write-Log -Message "Błąd zaznaczania: $($_.Exception.Message)" -Type 'Error' }
    }
    KeyDown       = {
        param($s, $e)
        try {
            if ($e.Key -ne [System.Windows.Input.Key]::Space) { return }
            $p = $script:TargetPanels[$s]
            $rows = @($s.SelectedItems | Where-Object { $_ -is [System.Data.DataRowView] })
            if ($rows.Count -eq 0) { return }
            $value = -not [bool]$rows[0].Row['Sel']
            foreach ($r in $rows) { $r.Row['Sel'] = $value }
            Update-HTTargetCount $p
            $e.Handled = $true
        }
        catch { Write-Verbose $_ }
    }
    SelectionChanged = {
        param($s, $e)
        try {
            $p = $script:TargetPanels[$s]
            Update-HTTargetCount $p
            $m = $script:UI.ActiveModule
            if ($m -and $m.OnTargetChange) { Invoke-HTUiAction -Module $m -Action $m.OnTargetChange }
        }
        catch { Write-Verbose $_ }
    }
    SearchChanged = {
        param($s, $e)
        try { Update-HTTargetFilter $script:TargetPanels[$s] } catch { Write-Verbose $_ }
    }
    ButtonClick   = {
        param($s, $e)
        try {
            $p = $script:TargetPanels[$s]
            $mode = [string]$s.Tag
            if ($mode -eq 'Paste') { Select-HTTargetsFromList -Panel $p }
            else { Set-HTTargetCheck -Panel $p -Mode $mode }
        }
        catch { Show-HTError 'Nie można zaznaczyć obiektów.' $_ }
    }
}

function New-HTTargetPanel {
    <#
        Lista obiektów (lewy panel): -Key, -Title, -Placeholder, -EmptyIcon, -EmptyText.
        Obiekty wczytuje Set-HTTargetItems; -Describe { param($o) @{ Key; Title; Sub; Dot; Search } } opisuje wiersz.
        -Tree: zamiast listy drzewo (np. biblioteki i foldery SharePoint).
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Title,
        [string]$Placeholder = 'Szukaj…',
        [string]$EmptyIcon = 'E721',
        [string]$EmptyText = 'Lista jest pusta - kliknij «Wczytaj».',
        [scriptblock]$Describe,
        [switch]$Tree
    )
    $root = New-HTUiElement $script:TargetPanelXaml
    $p = @{ Key = $Key; Root = $root; EmptyText = $EmptyText; Describe = $Describe; Objects = @{}; Buttons = New-Object System.Collections.ArrayList; IsTree = [bool]$Tree }
    foreach ($n in 'pTitle', 'pCount', 'pSource', 'pSearch', 'pList', 'pTree', 'pEmpty', 'pEmptyIcon', 'pEmptyText', 'pAll', 'pNone', 'pInvert', 'pPaste', 'pSel', 'pSelButtons') { $p[$n] = $root.FindName($n) }
    $p.pTitle.Text = $Title.ToUpperInvariant()
    $p.pSearch.Tag = $Placeholder
    $p.pEmptyIcon.Text = Get-HTGlyph $EmptyIcon
    $p.pEmptyText.Text = $EmptyText
    $p.pAll.Content = New-HTIconContent -Text '' -Icon 'E8B3' -IconSize 13
    $p.pNone.Content = New-HTIconContent -Text '' -Icon 'E894' -IconSize 13
    $p.pInvert.Content = New-HTIconContent -Text '' -Icon 'E8AB' -IconSize 13
    $p.pPaste.Content = New-HTIconContent -Text '' -Icon 'E8FD' -IconSize 13

    $t = New-Object System.Data.DataTable $Key
    [void]$t.Columns.Add('Sel', [bool])
    foreach ($c in 'Key', 'Title', 'Sub', 'Dot', 'Search') { [void]$t.Columns.Add($c, [string]) }
    $t.Columns['Sel'].DefaultValue = $false
    $t.Columns['Dot'].DefaultValue = $script:DotColors.unknown
    $t.PrimaryKey = [System.Data.DataColumn[]]@($t.Columns['Key'])
    $t.CaseSensitive = $false
    $view = [System.Data.DataView]::new($t)
    $view.Sort = 'Title ASC'
    $p.Table = $t
    $p.View = $view
    $p.pList.ItemsSource = $view

    $script:TargetPanels[$p.pList] = $p
    $script:TargetPanels[$p.pSearch] = $p
    $p.pList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]$script:TargetEvents.ItemClick)
    $p.pList.add_PreviewKeyDown($script:TargetEvents.KeyDown)
    $p.pList.add_SelectionChanged($script:TargetEvents.SelectionChanged)
    $p.pSearch.add_TextChanged($script:TargetEvents.SearchChanged)
    foreach ($pair in @(@('pAll', 'CheckVisible'), @('pNone', 'UncheckAll'), @('pInvert', 'InvertVisible'), @('pPaste', 'Paste'))) {
        $script:TargetPanels[$p[$pair[0]]] = $p
        $p[$pair[0]].Tag = $pair[1]
        $p[$pair[0]].add_Click($script:TargetEvents.ButtonClick)
    }
    if ($Tree) {
        $p.pList.Visibility = 'Collapsed'
        $p.pTree.Visibility = 'Visible'
        $p.pSearch.Visibility = 'Collapsed'
        $p.pAll.Visibility = 'Collapsed'
        $p.pInvert.Visibility = 'Collapsed'
        $p.pPaste.Visibility = 'Collapsed'
        $script:TargetPanels[$p.pTree] = $p
        $script:TargetPanels[$p.pNone] = $p
    }
    $script:UI.Panels[$Key] = $p
    Update-HTTargetCount $p
    return $p
}

function Add-HTPanelButton {
    # Przycisk w karcie źródła panelu (np. «Wczytaj»); akcja dostaje panel: { param($p) }
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][string]$Text, [string]$Icon = '', [Parameter(Mandatory)][scriptblock]$OnClick, [switch]$Primary, [string]$ToolTip = '', $Parent = $null)
    $b = New-HTButton -Text $Text -Icon $Icon -Primary:$Primary -ToolTip $ToolTip
    $b.Margin = '0,0,8,6'
    $b.Tag = @{ Panel = $Panel; Action = $OnClick }
    $b.add_Click({
            param($s, $e)
            try { $null = & $s.Tag.Action $s.Tag.Panel }
            catch {
                Write-Log -Message "Błąd: $($_.Exception.Message)" -Type 'Error'
                Show-HTError 'Operacja nie powiodła się.' $_
            }
        })
    [void]$Panel.Buttons.Add($b)
    $target = if ($Parent) { $Parent } else {
        if (-not $Panel['SourceRow']) {
            $wrap = New-Object System.Windows.Controls.WrapPanel
            [void]$Panel.pSource.Children.Add($wrap)
            $Panel.SourceRow = $wrap
        }
        $Panel.SourceRow
    }
    [void]$target.Children.Add($b)
    return $b
}

function Add-HTPanelHint {
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][string]$Text)
    $t = New-HTDialogText -Text $Text -Color '#7B8496' -Size 11.5
    $t.Margin = '0,0,0,6'
    [void]$Panel.pSource.Children.Add($t)
    return $t
}

function Set-HTTargetItems {
    # Wczytuje obiekty do listy (zachowuje zaznaczenia obiektów o tym samym kluczu)
    param([Parameter(Mandatory)][hashtable]$Panel, [AllowEmptyCollection()][object[]]$Items)
    $t = $Panel.Table
    $checked = @{}
    foreach ($r in $t.Select('Sel = true')) { $checked[[string]$r['Key']] = $true }
    $Panel.Objects = @{}
    $t.BeginLoadData()
    try {
        $t.Rows.Clear()
        foreach ($o in @($Items)) {
            if ($null -eq $o) { continue }
            $d = & $Panel.Describe $o
            $k = [string]$d.Key
            if (-not $k -or $Panel.Objects.ContainsKey($k)) { continue }
            $Panel.Objects[$k] = $o
            $row = $t.NewRow()
            $row['Key'] = $k
            $row['Title'] = [string]$d.Title
            $row['Sub'] = [string]$d.Sub
            $row['Dot'] = $(if ($d.Dot) { if ($script:DotColors.ContainsKey([string]$d.Dot)) { $script:DotColors[[string]$d.Dot] } else { [string]$d.Dot } } else { $script:DotColors.unknown })
            $row['Search'] = ("$($d.Title) $($d.Sub) $($d.Search)").ToLowerInvariant()
            $row['Sel'] = $checked.ContainsKey($k)
            $t.Rows.Add($row)
        }
    }
    finally { $t.EndLoadData() }
    Update-HTTargetFilter $Panel
}

function Update-HTTargetItem {
    # Odświeża opis jednego obiektu po zmianie (np. konto zablokowane)
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][object]$Item)
    $d = & $Panel.Describe $Item
    $row = $Panel.Table.Rows.Find([string]$d.Key)
    if (-not $row) { return }
    $Panel.Objects[[string]$d.Key] = $Item
    $row['Title'] = [string]$d.Title
    $row['Sub'] = [string]$d.Sub
    $row['Dot'] = $(if ($d.Dot -and $script:DotColors.ContainsKey([string]$d.Dot)) { $script:DotColors[[string]$d.Dot] } elseif ($d.Dot) { [string]$d.Dot } else { $script:DotColors.unknown })
    $row['Search'] = ("$($d.Title) $($d.Sub) $($d.Search)").ToLowerInvariant()
}

function Remove-HTTargetItem {
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][object]$Item)
    $d = & $Panel.Describe $Item
    $row = $Panel.Table.Rows.Find([string]$d.Key)
    if ($row) { $Panel.Table.Rows.Remove($row) }
    [void]$Panel.Objects.Remove([string]$d.Key)
    Update-HTTargetCount $Panel
}

function Update-HTTargetCount {
    param([hashtable]$Panel)
    if (-not $Panel) { return }
    if ($Panel.IsTree) {
        $checked = @(Get-HTTreeChecked -Panel $Panel).Count
        $Panel.pCount.Text = [string]$Panel.pTree.Items.Count
        $Panel.pSel.Text = if ($checked -gt 0) { "zaznaczone: $checked" } else { '' }
        $Panel.pEmpty.Visibility = if ($Panel.pTree.Items.Count -gt 0) { 'Collapsed' } else { 'Visible' }
        return
    }
    $t = $Panel.Table
    $selected = @($t.Select('Sel = true')).Count
    $Panel.pCount.Text = [string]$t.Rows.Count
    $Panel.pSel.Text = if ($Panel.View.Count -ne $t.Rows.Count) { "zaznaczone: $selected • widoczne: $($Panel.View.Count)" } else { "zaznaczone: $selected z $($t.Rows.Count)" }
    $Panel.pSel.Foreground = Get-HTBrush $(if ($selected -gt 0) { '#8CB0FF' } else { '#7B8496' })
    if ($Panel.View.Count -gt 0) { $Panel.pEmpty.Visibility = 'Collapsed' }
    else {
        $Panel.pEmpty.Visibility = 'Visible'
        $Panel.pEmptyText.Text = if ($t.Rows.Count -gt 0) { 'Nic nie pasuje do wyszukiwania' } else { $Panel.EmptyText }
    }
}

function Update-HTTargetFilter {
    param([hashtable]$Panel)
    $text = $Panel.pSearch.Text.Trim().ToLowerInvariant()
    $terms = @($text -split '\s+' | Where-Object { $_ })
    $parts = foreach ($term in $terms) { "Search LIKE '*{0}*'" -f (ConvertTo-HTLikeLiteral $term) }
    try { $Panel.View.RowFilter = (@($parts) -join ' AND ') } catch { $Panel.View.RowFilter = '' }
    Update-HTTargetCount $Panel
}

function Set-HTTargetCheck {
    param([hashtable]$Panel, [ValidateSet('CheckVisible', 'UncheckAll', 'InvertVisible')][string]$Mode)
    if ($Panel.IsTree) {
        foreach ($node in @(Get-HTTreeNodes -Panel $Panel)) {
            $cb = if ($node.Header -is [System.Windows.Controls.Panel]) { $node.Header.Children[0] } else { $null }
            if ($cb -is [System.Windows.Controls.CheckBox]) { $cb.IsChecked = $false }
        }
        Update-HTTargetCount $Panel
        return
    }
    $t = $Panel.Table
    switch ($Mode) {
        'CheckVisible' { foreach ($drv in @($Panel.View | ForEach-Object { $_ })) { $drv.Row['Sel'] = $true } }
        'UncheckAll' { foreach ($r in $t.Rows) { if ([bool]$r['Sel']) { $r['Sel'] = $false } } }
        'InvertVisible' { foreach ($drv in @($Panel.View | ForEach-Object { $_ })) { $drv.Row['Sel'] = -not [bool]$drv.Row['Sel'] } }
    }
    Update-HTTargetCount $Panel
}

function Select-HTTargetsFromList {
    # Zaznacza obiekty wskazane listą (wklejoną lub z pliku): dopasowanie do tytułu, opisu i pól wyszukiwania
    param([Parameter(Mandatory)][hashtable]$Panel)
    if ($Panel.Table.Rows.Count -eq 0) { Show-HTWarning 'Najpierw wczytaj listę obiektów.'; return }
    $text = Show-InputBox -Title 'Zaznacz z listy' -Prompt 'Wklej identyfikatory (UPN, e-mail, login lub nazwę) - jeden w linii, albo zostaw puste i wczytaj plik CSV/TXT.' -Multiline -AllowEmpty -Icon 'E8FD'
    if ($null -eq $text) { return }
    $ids = @(Split-HTInputList -Text $text)
    if ($ids.Count -eq 0) {
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Title = 'Wczytaj identyfikatory'
        $dialog.Filter = 'CSV lub TXT (*.csv;*.txt)|*.csv;*.txt|Wszystkie pliki (*.*)|*.*'
        if ($dialog.ShowDialog() -ne $true) { return }
        $ids = @(Import-HTIdentityFile -Path $dialog.FileName)
    }
    if ($ids.Count -eq 0) { return }
    $found = 0
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($id in $ids) {
        $needle = $id.ToLowerInvariant()
        $match = $null
        foreach ($r in $Panel.Table.Rows) {
            $words = @(([string]$r['Search']) -split '\s+')
            if ([string]$r['Key'] -eq $id -or ([string]$r['Title']).ToLowerInvariant() -eq $needle -or $words -contains $needle) { $match = $r; break }
        }
        if ($match) { $match['Sel'] = $true; $found++ } else { $missing.Add($id) }
    }
    Update-HTTargetCount $Panel
    if ($missing.Count -gt 0) {
        Show-HTWarning -Title 'Zaznacz z listy' -Text ("Zaznaczono: $found z $($ids.Count).`nNie znaleziono na liście:`n" + (($missing | Select-Object -First 40) -join "`n"))
    }
    else { Show-HTToast "Zaznaczono obiektów: $found." 'ok' }
}

function Get-HTTargets {
    <#
        Obiekty docelowe modułu: zaznaczone polami wyboru, a gdy nic nie zaznaczono - podświetlone na liście.
        -Single: dokładnie jeden obiekt (pierwszy). Wyświetla ostrzeżenie, gdy lista jest pusta.
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [switch]$Single, [switch]$Quiet)
    $p = $script:UI.Panels[$Module.Panel]
    if (-not $p) { return @() }
    $result = @()
    if ($p.IsTree) {
        $result = @(Get-HTTreeChecked -Panel $p)
        if ($result.Count -eq 0 -and $p.pTree.SelectedItem) { $result = @($p.pTree.SelectedItem.Tag) }
    }
    else {
        $rows = @($p.Table.Select('Sel = true'))
        if ($rows.Count -eq 0) { $rows = @($p.pList.SelectedItems | ForEach-Object { $_.Row }) }
        $result = @($rows | ForEach-Object { $p.Objects[[string]$_['Key']] } | Where-Object { $null -ne $_ })
    }
    if ($result.Count -eq 0) {
        if (-not $Quiet) { Show-HTWarning 'Zaznacz obiekty na liście po lewej (pole wyboru) albo kliknij jeden z nich.' -Title 'Brak obiektów' }
        return @()
    }
    if ($Single) { return @($result[0]) }
    return $result
}

function Get-HTChangeTargets {
    <#
        Obiekty do zmiany (zasada trzech etapów: zakres -> sprawdzenie stanu -> zmiana): wiersze zaznaczone w wynikach
        (np. po «Sprawdź stan»), a bez zaznaczenia w wynikach - obiekty zaznaczone na liście po lewej.
        Źródło trafia do okna potwierdzenia zmiany. -Single: dokładnie jeden obiekt.
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [switch]$Single)
    $fromResults = @(Get-HTSelectedResultTargets -Module $Module)
    if ($fromResults.Count) {
        if ($Single -and $fromResults.Count -gt 1) {
            Show-HTWarning 'Ta operacja dotyczy jednego obiektu - zaznacz w wynikach jeden wiersz.' -Title 'Za dużo obiektów'
            return @()
        }
        $script:UI.TargetSource = 'wiersze zaznaczone w wynikach'
        return $fromResults
    }
    $script:UI.TargetSource = 'zaznaczone na liście'
    return @(Get-HTTargets -Module $Module -Single:$Single)
}

function Get-HTPanel([string]$Key) { return $script:UI.Panels[$Key] }

# Drzewo (SharePoint): węzły z polem wyboru; Tag węzła = obiekt
# Shift + kliknięcie pola wyboru w drzewie: zakres elementów tego samego poziomu od ostatnio klikniętego
$script:TreeCheckEvents = @{
    Click = {
        param($s, $e)
        try {
            $node = $s.Parent.Parent
            if ($node -isnot [System.Windows.Controls.TreeViewItem]) { return }
            $last = $script:TreeLastChecked
            $shift = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift) -ne 0
            if ($shift -and $last -and -not [object]::ReferenceEquals($last, $node) -and [object]::ReferenceEquals($last.Parent, $node.Parent)) {
                $items = @($node.Parent.Items)
                $a = [array]::IndexOf($items, $last)
                $b = [array]::IndexOf($items, $node)
                if ($a -ge 0 -and $b -ge 0) {
                    foreach ($i in ([Math]::Min($a, $b))..([Math]::Max($a, $b))) {
                        $item = $items[$i]
                        if ($item -is [System.Windows.Controls.TreeViewItem] -and $item.Header -is [System.Windows.Controls.Panel]) {
                            $box = $item.Header.Children[0]
                            if ($box -is [System.Windows.Controls.CheckBox]) { $box.IsChecked = $s.IsChecked }
                        }
                    }
                }
            }
            $script:TreeLastChecked = $node
        }
        catch { Write-Verbose "Zaznaczanie zakresu w drzewie: $_" }
    }
}

function Remove-HTTreeItem {
    # Usunięcie z drzewa węzłów, których obiektem (Tag) jest -Item (np. po usunięciu folderu)
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][object]$Item)
    foreach ($n in @(Get-HTTreeNodes -Panel $Panel)) {
        if ([object]::ReferenceEquals($n.Tag, $Item) -and $n.Parent -is [System.Windows.Controls.ItemsControl]) { $n.Parent.Items.Remove($n) }
    }
}

function New-HTTreeItem {
    param([Parameter(Mandatory)][object]$Item, [string]$Text, [string]$Icon = 'E8B7', [switch]$Lazy)
    $node = New-Object System.Windows.Controls.TreeViewItem
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Focusable = $false
    $cb.Margin = '0,0,8,0'
    $cb.ToolTip = 'Shift + kliknięcie - zaznacza (albo odznacza) wszystkie elementy pomiędzy, na tym samym poziomie'
    $cb.add_Click($script:TreeCheckEvents.Click)
    [void]$sp.Children.Add($cb)
    $glyph = New-HTGlyphBlock -Code $Icon -Size 13 -Color '#8CB0FF'
    $glyph.Margin = '0,0,8,0'
    [void]$sp.Children.Add($glyph)
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Text
    $label.VerticalAlignment = 'Center'
    [void]$sp.Children.Add($label)
    $node.Header = $sp
    $node.Tag = $Item
    $node.ToolTip = [string]$Item.ServerRelativeUrl
    if ($Lazy) {
        $placeholder = New-Object System.Windows.Controls.TreeViewItem
        $placeholder.Header = 'Ładowanie…'
        $placeholder.Tag = '__placeholder__'
        [void]$node.Items.Add($placeholder)
    }
    return $node
}

function Get-HTTreeNodes {
    param([Parameter(Mandatory)][hashtable]$Panel)
    $stack = New-Object System.Collections.Stack
    foreach ($n in $Panel.pTree.Items) { $stack.Push($n) }
    while ($stack.Count -gt 0) {
        $n = $stack.Pop()
        if ($n.Tag -eq '__placeholder__') { continue }
        $n
        foreach ($child in $n.Items) { $stack.Push($child) }
    }
}

function Get-HTTreeChecked {
    param([Parameter(Mandatory)][hashtable]$Panel)
    foreach ($n in @(Get-HTTreeNodes -Panel $Panel)) {
        $cb = if ($n.Header -is [System.Windows.Controls.Panel]) { $n.Header.Children[0] } else { $null }
        if ($cb -is [System.Windows.Controls.CheckBox] -and $cb.IsChecked -eq $true) { $n.Tag }
    }
}
#endregion

#region Widok modułu: nagłówek, parametry, kafelki, tabela wyników z panelem szczegółów
$script:ModuleViewXaml = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Grid.RowDefinitions>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="*" MinHeight="160"/>
  </Grid.RowDefinitions>

  <Grid Margin="0,0,0,16">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <Border Width="44" Height="44" CornerRadius="11" Background="#1A2640" BorderBrush="#2F4478" BorderThickness="1" VerticalAlignment="Top">
      <TextBlock x:Name="hdrIcon" Style="{StaticResource Glyph}" FontSize="20" Foreground="#8CB0FF" HorizontalAlignment="Center"/>
    </Border>
    <StackPanel Grid.Column="1" Margin="14,0,0,0" VerticalAlignment="Center">
      <StackPanel Orientation="Horizontal">
        <TextBlock x:Name="hdrTitle" FontSize="20" FontWeight="SemiBold" Foreground="White"/>
        <Border Style="{StaticResource Chip}" Margin="12,2,0,0">
          <TextBlock x:Name="hdrCategory" FontSize="11" Foreground="#8791A5"/>
        </Border>
      </StackPanel>
      <TextBlock x:Name="hdrDesc" Foreground="#8791A5" TextWrapping="Wrap" Margin="0,4,0,0" MaxWidth="1000" HorizontalAlignment="Left"/>
    </StackPanel>
    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Top">
      <Border x:Name="busyChip" Style="{StaticResource Chip}" Background="#1A2640" Padding="12,5" Visibility="Collapsed" VerticalAlignment="Center">
        <StackPanel Orientation="Horizontal">
          <Ellipse Width="8" Height="8" Fill="#4C7DF0" Margin="0,0,8,0" VerticalAlignment="Center"/>
          <TextBlock x:Name="busyText" Text="Trwa operacja…" Foreground="#8CC0FF" FontSize="12" VerticalAlignment="Center" MaxWidth="360" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
      </Border>
      <Button x:Name="btnBusyStop" Style="{StaticResource DangerButton}" MinHeight="26" Padding="10,2" Margin="8,0,0,0" Visibility="Collapsed" VerticalAlignment="Center"
              ToolTip="Przerwij (Esc): zapytanie w tle od razu, operację na wielu obiektach - po bieżącym obiekcie. Wyniki zostaną w tabeli.">
        <StackPanel Orientation="Horizontal">
          <TextBlock FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Text="&#xE71A;" FontSize="11" Margin="0,0,7,0" VerticalAlignment="Center"/>
          <TextBlock Text="Przerwij" FontSize="12" VerticalAlignment="Center"/>
        </StackPanel>
      </Button>
      <Button x:Name="btnCollapse" Style="{StaticResource GhostButton}" Padding="8,4" MinHeight="28" ToolTip="Zwiń / rozwiń panel parametrów"/>
    </StackPanel>
  </Grid>

  <Border x:Name="paramsCard" Grid.Row="1" Style="{StaticResource Card}" Padding="16,14,10,8" Margin="0,0,0,12" Visibility="Collapsed">
    <StackPanel x:Name="paramsStack"/>
  </Border>

  <UniformGrid x:Name="statsGrid" Grid.Row="2" Rows="1" Margin="0,0,-10,12" Visibility="Collapsed"/>

  <Grid Grid.Row="3" Margin="2,0,0,8">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <TextBlock Text="Wyniki" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/>
    <Border Grid.Column="1" Style="{StaticResource Chip}" Margin="10,0,0,0">
      <TextBlock x:Name="countText" Text="0" Foreground="#AEB6C4" FontSize="11.5"/>
    </Border>
    <Button x:Name="btnFilters" Grid.Column="2" Style="{StaticResource GhostButton}" Foreground="#8CB0FF" Background="#1A2640" Padding="10,3" MinHeight="26" Margin="8,0,0,0" Visibility="Collapsed"/>
    <TextBlock x:Name="resultHint" Grid.Column="3" Foreground="#5E6779" FontSize="12" VerticalAlignment="Center" Margin="6,0,12,0" TextTrimming="CharacterEllipsis"/>
    <TextBox x:Name="filterBox" Grid.Column="4" Width="260" Tag="Filtruj wyniki (Ctrl+F)…" Margin="0,0,8,0"/>
    <CheckBox x:Name="chkReveal" Grid.Column="5" Content="Pokaż poufne" Margin="4,0,12,0" Visibility="Collapsed"/>
    <Button x:Name="btnViews" Grid.Column="6" Style="{StaticResource GhostButton}" ToolTip="Zapisane widoki: filtr, filtry kolumn i ukryte kolumny tego modułu" Margin="0,0,4,0"/>
    <StackPanel Grid.Column="7" Orientation="Horizontal">
      <Button x:Name="btnEmptyCols" Style="{StaticResource GhostButton}" ToolTip="Ukryj kolumny bez wartości (kliknij ponownie, aby je pokazać)" Margin="0,0,4,0"/>
      <Button x:Name="btnColumns" Style="{StaticResource GhostButton}" ToolTip="Wybierz kolumny do pokazania - ukryte nie trafiają do kopiowania ani eksportu" Margin="0,0,4,0"/>
    </StackPanel>
    <Button x:Name="btnDetail" Grid.Column="8" Style="{StaticResource GhostButton}" ToolTip="Panel szczegółów wiersza" Margin="0,0,4,0"/>
    <Button x:Name="btnCopy" Grid.Column="9" Style="{StaticResource GhostButton}" ToolTip="Kopiuj zaznaczone wiersze lub całą tabelę (format Excel)" Margin="0,0,4,0"/>
    <Button x:Name="btnMail" Grid.Column="10" Style="{StaticResource GhostButton}" ToolTip="Wyślij widoczne wyniki e-mailem (Excel, raport HTML lub CSV w załączniku)" Margin="0,0,4,0"/>
    <Button x:Name="btnExport" Grid.Column="11" ToolTip="Eksport widocznych wierszy: Excel, CSV, raport HTML albo JSON"/>
  </Grid>

  <Border Grid.Row="4" Style="{StaticResource Card}" Padding="0">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*" MinWidth="300"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition x:Name="detailCol" Width="340" MinWidth="0"/>
      </Grid.ColumnDefinitions>
      <DataGrid x:Name="grid" Style="{StaticResource DarkGrid}" AutoGenerateColumns="False" Margin="1,1,1,6" CanUserReorderColumns="True"/>
      <StackPanel x:Name="emptyState" HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False" Margin="20,40,20,20">
        <Border Width="64" Height="64" CornerRadius="32" Background="#1A2029" HorizontalAlignment="Center">
          <TextBlock x:Name="emptyIcon" Style="{StaticResource Glyph}" FontSize="26" Foreground="#4A5568" HorizontalAlignment="Center"/>
        </Border>
        <TextBlock x:Name="emptyText" Text="Brak wyników" FontSize="15" FontWeight="SemiBold" Foreground="#AEB6C4" HorizontalAlignment="Center" Margin="0,14,0,0"/>
        <TextBlock x:Name="emptyHint" Foreground="#5E6779" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" MaxWidth="440" Margin="0,5,0,0"/>
      </StackPanel>
      <GridSplitter x:Name="detailSplit" Grid.Column="1" Width="5" HorizontalAlignment="Stretch" ResizeBehavior="PreviousAndNext"/>
      <Border x:Name="detailPane" Grid.Column="2" BorderBrush="#242B36" BorderThickness="1,0,0,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid Margin="14,12,8,6">
            <TextBlock Text="SZCZEGÓŁY WIERSZA" Foreground="#5E6779" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center"/>
            <Button x:Name="btnDetailCopy" Style="{StaticResource GhostButton}" HorizontalAlignment="Right" Padding="6,2" MinHeight="24" ToolTip="Kopiuj szczegóły"/>
          </Grid>
          <TextBox x:Name="detailText" Grid.Row="1" Style="{StaticResource ReadOnlyText}" FontFamily="Segoe UI" FontSize="12.5" Margin="8,0,4,8" Padding="6,0"/>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Grid>
'@

$script:GridModules = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:FilterTimer = $null
$script:FilterPending = $null
$script:GridEvents = @{
    SelectionChanged   = {
        param($s, $e)
        try {
            $m = $null
            if ($script:GridModules.TryGetValue($s, [ref]$m)) { Update-HTDetailText -Module $m }
        }
        catch { Write-Verbose $_ }
    }
    MouseDoubleClick   = {
        param($s, $e)
        try {
            $m = $null
            if (-not $script:GridModules.TryGetValue($s, [ref]$m)) { return }
            $dep = $e.OriginalSource
            while ($dep -and -not ($dep -is [System.Windows.Controls.DataGridRow])) {
                if ($dep -is [System.Windows.Controls.Primitives.DataGridColumnHeader] -or $dep -is [System.Windows.Controls.Primitives.ScrollBar]) { return }
                if ($dep -is [System.Windows.Media.Visual] -or $dep -is [System.Windows.Media.Media3D.Visual3D]) { $dep = [System.Windows.Media.VisualTreeHelper]::GetParent($dep) }
                else { $dep = $null }
            }
            if (-not $dep) { return }
            $drv = $dep.Item
            if (-not ($drv -is [System.Data.DataRowView])) { return }
            if ($m.RowDoubleClick) { Invoke-HTUiAction -Module $m -Action $m.RowDoubleClick -Source $drv }
            else { Show-HTRowDetails -Module $m -Row $drv }
        }
        catch { Write-Log -Message "Nie można wyświetlić szczegółów: $($_.Exception.Message)" -Type 'Error' }
    }
    ContextMenuOpening = {
        param($s, $e)
        try {
            $m = $null
            if (-not $script:GridModules.TryGetValue($s, [ref]$m)) { return }
            # Nagłówek kolumny - menu kolumny; komórka - zapamiętana do szybkiego filtra po wartości
            $m.MenuCell = $null
            $hdr = Find-HTVisualParent -Element $e.OriginalSource -Type ([System.Windows.Controls.Primitives.DataGridColumnHeader])
            if ($hdr) {
                if (-not $hdr.Column) { $e.Handled = $true; return }
                $m.MenuCell = @{ Column = [string]$hdr.Column.SortMemberPath; Row = $null; Header = $true }
            }
            else {
                $cell = Find-HTVisualParent -Element $e.OriginalSource -Type ([System.Windows.Controls.DataGridCell])
                if ($cell -and $cell.Column -and $cell.DataContext -is [System.Data.DataRowView]) { $m.MenuCell = @{ Column = [string]$cell.Column.SortMemberPath; Row = $cell.DataContext; Header = $false } }
            }
            Update-HTGridMenu -Module $m
        }
        catch { Write-Verbose $_ }
    }
}

function New-HTModuleView {
    param([Parameter(Mandatory)][hashtable]$Module)
    $root = New-HTUiElement $script:ModuleViewXaml
    $Module.Root = $root
    foreach ($n in 'paramsCard', 'paramsStack', 'statsGrid', 'busyChip', 'busyText', 'btnBusyStop', 'countText', 'btnFilters', 'resultHint', 'filterBox', 'chkReveal',
        'btnViews', 'btnColumns', 'btnEmptyCols', 'btnDetail', 'btnCopy', 'btnMail', 'btnExport', 'grid', 'emptyState', 'emptyIcon', 'emptyText', 'emptyHint', 'detailCol', 'detailSplit',
        'detailPane', 'detailText', 'btnDetailCopy', 'btnCollapse') {
        $Module.View_[$n] = $root.FindName($n)
    }
    $Module.ParamsCard = $Module.View_['paramsCard']
    $Module.ParamsStack = $Module.View_['paramsStack']
    $Module.StatsGrid = $Module.View_['statsGrid']
    $Module.Grid = $Module.View_['grid']
    # Ctrl+C z nagłówkami: nazwa kolumny zamiast elementu nagłówka (nazwa + lejek filtra)
    if ($Module.Grid) { $Module.Grid.add_CopyingRowClipboardContent($script:GridCopyEvents.CopyRow) }
    $Module.FilterBox = $Module.View_['filterBox']

    $root.FindName('hdrIcon').Text = Get-HTGlyph $Module.Icon
    $root.FindName('hdrTitle').Text = $Module.Title
    $root.FindName('hdrCategory').Text = $(if ($Module.WorkspaceTitle) { $Module.WorkspaceTitle + '  •  ' + $Module.Category } else { $Module.Category })
    $desc = $root.FindName('hdrDesc')
    if ($Module.Description) { $desc.Text = $Module.Description } else { $desc.Visibility = 'Collapsed' }

    $v = $Module.View_
    $v.btnBusyStop.add_Click({ Stop-HTBackground })
    $v.btnDetail.Content = New-HTIconContent -Text '' -Icon 'E8A1'
    $v.btnColumns.Content = New-HTIconContent -Text '' -Icon 'E8FD'
    $v.btnEmptyCols.Content = New-HTIconContent -Text '' -Icon 'ED1A'
    $v.btnViews.Content = New-HTIconContent -Text '' -Icon 'E71D'
    $v.btnCopy.Content = New-HTIconContent -Text '' -Icon 'E8C8'
    $v.btnMail.Content = New-HTIconContent -Text '' -Icon 'E715'
    $v.btnExport.Content = New-HTIconContent -Text 'Eksport' -Icon 'EDE1'
    $v.btnDetailCopy.Content = New-HTIconContent -Text '' -Icon 'E8C8' -IconSize 11
    $v.btnCollapse.Content = New-HTIconContent -Text '' -Icon 'E70E' -IconSize 12
    $v.btnCollapse.Visibility = 'Collapsed'
    Register-HTControlHandler -Control $v.btnCollapse -EventName 'Click' -Module $Module -Action {
        param($m)
        $collapsed = $m.ParamsCard.Visibility -eq 'Visible'
        $m.ParamsCard.Visibility = if ($collapsed) { 'Collapsed' } else { 'Visible' }
        $m.View_.btnCollapse.Content = New-HTIconContent -Text $(if ($collapsed) { 'Parametry' } else { '' }) -Icon $(if ($collapsed) { 'E70D' } else { 'E70E' }) -IconSize 12
    }
    Register-HTControlHandler -Control $v.filterBox -EventName 'TextChanged' -Module $Module -Action { param($m) Request-HTResultFilter -Module $m }
    Register-HTControlHandler -Control $v.btnCopy -EventName 'Click' -Module $Module -Action { param($m) Copy-HTResultView -Module $m }
    Register-HTControlHandler -Control $v.btnExport -EventName 'Click' -Module $Module -Action { param($m) Export-HTResultView -Module $m }
    Register-HTControlHandler -Control $v.btnColumns -EventName 'Click' -Module $Module -Action { param($m) Select-HTResultColumns -Module $m }
    Register-HTControlHandler -Control $v.btnEmptyCols -EventName 'Click' -Module $Module -Action { param($m) Switch-HTEmptyColumns -Module $m }
    Register-HTControlHandler -Control $v.btnViews -EventName 'Click' -Module $Module -Action { param($m, $s) Show-HTViewsMenu -Module $m -Anchor $s }
    Register-HTControlHandler -Control $v.btnMail -EventName 'Click' -Module $Module -Action { param($m) Send-HTResultMail -Module $m }
    # Zapisane widoki i ukryte kolumny dotyczą modułów nawigacji (nie okien podglądu)
    if (-not $Module.Workspace) { $v.btnViews.Visibility = 'Collapsed' }
    Register-HTControlHandler -Control $v.btnFilters -EventName 'Click' -Module $Module -Action { param($m) Clear-HTColumnFilters -Module $m; Show-HTToast 'Wyczyszczono filtry kolumn.' 'info' 2 }
    Register-HTControlHandler -Control $v.btnDetail -EventName 'Click' -Module $Module -Action {
        param($m)
        $script:UI.DetailVisible = -not $script:UI.DetailVisible
        foreach ($other in $script:UI.Modules.Values) { if ($other.Root) { Update-HTDetailPane -Module $other } }
    }
    Register-HTControlHandler -Control $v.btnDetailCopy -EventName 'Click' -Module $Module -Action {
        param($m)
        $t = $m.View_['detailText'].Text
        if ($t) { Set-HTClipboard $t; Show-HTToast 'Skopiowano szczegóły wiersza.' 'ok' }
    }
    Register-HTControlHandler -Control $v.chkReveal -EventName 'Checked' -Module $Module -Action { param($m) Set-HTSecretReveal -Module $m -Reveal $true }
    Register-HTControlHandler -Control $v.chkReveal -EventName 'Unchecked' -Module $Module -Action { param($m) Set-HTSecretReveal -Module $m -Reveal $false }

    $grid = $Module.Grid
    $script:GridModules[$grid] = $Module
    $grid.add_SelectionChanged($script:GridEvents.SelectionChanged)
    $grid.add_MouseDoubleClick($script:GridEvents.MouseDoubleClick)
    $grid.add_ContextMenuOpening($script:GridEvents.ContextMenuOpening)
    $grid.ContextMenu = New-Object System.Windows.Controls.ContextMenu
    Reset-HTResults -Module $Module
    Update-HTDetailPane -Module $Module
}

function Complete-HTModuleView {
    param([Parameter(Mandatory)][hashtable]$Module)
    $v = $Module.View_
    if ($Module.ParamsStack.Children.Count -gt 0) { $v.btnCollapse.Visibility = 'Visible' }
    if ($Module.SecretColumns.Count -gt 0) { $v.chkReveal.Visibility = 'Visible' }
    $v.emptyIcon.Text = Get-HTGlyph $Module.Icon
    if (-not $Module.EmptyHint -and $Module.PrimaryButton) {
        $label = $Module.PrimaryButton.Content
        if ($label -is [System.Windows.Controls.Panel]) { $label = $label.Children[$label.Children.Count - 1].Text }
        $Module.EmptyHint = if ($Module.Panel) { "Zaznacz obiekty na liście po lewej i kliknij «$label» (F5)." } else { "Kliknij «$label» (F5), aby pobrać dane." }
    }
    if ($Module.ResultHint) { $v.resultHint.Text = $Module.ResultHint }
    elseif ($Module.RowActions.Count -gt 0) { $v.resultHint.Text = 'Prawy przycisk myszy na wierszach - akcje' }
    else { $v.resultHint.Text = 'Dwuklik na wierszu - szczegóły' }
    Update-HTResultCount -Module $Module
}

function Add-HTParamRow {
    <#
        Wiersz panelu parametrów z podpisem po lewej (-Title) i dowolną zawartością. Kolumna podpisów jest wspólna dla
        wierszy modułu (SharedSizeGroup) i ma szerokość najdłuższego podpisu: gdy którykolwiek wiersz ma podpis, wiersze
        bez podpisu zaczynają się w kolumnie treści (np. przyciski zmian pod «Sprawdź stan»); bez podpisów - bez wcięcia.
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [string]$Title = '', [Parameter(Mandatory)]$Content)
    $stack = $Module.ParamsStack
    [System.Windows.Controls.Grid]::SetIsSharedSizeScope($stack, $true)
    $grid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::Auto
    $c1.SharedSizeGroup = 'HTParamCaption'
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    [void]$grid.ColumnDefinitions.Add($c1)
    [void]$grid.ColumnDefinitions.Add($c2)
    if ($Title) {
        $caption = New-Object System.Windows.Controls.TextBlock
        $caption.Text = $Title
        $caption.Foreground = Get-HTBrush '#8791A5'
        $caption.FontWeight = 'SemiBold'
        $caption.FontSize = 12
        # Kolumna podpisów tak szeroka jak najdłuższy podpis modułu (długie - zawijane), bez stałej przerwy
        $caption.MaxWidth = 150
        $caption.Margin = '0,8,14,0'
        $caption.VerticalAlignment = 'Top'
        $caption.TextWrapping = 'Wrap'
        [void]$grid.Children.Add($caption)
    }
    [System.Windows.Controls.Grid]::SetColumn($Content, 1)
    [void]$grid.Children.Add($Content)
    if ($stack.Children.Count -gt 0) { $grid.Margin = '0,4,0,0' }
    # Wiersz zmian (czerwone przyciski akcji na wierszach) zostaje ostatni - nowe wiersze trafiają przed niego
    $changeRow = $Module['ChangeRowContainer']
    if ($changeRow -and $stack.Children.Contains($changeRow)) {
        [void]$stack.Children.Insert($stack.Children.IndexOf($changeRow), $grid)
        $changeRow.Margin = '0,4,0,0'
    }
    else { [void]$stack.Children.Add($grid) }
    $Module.ParamsCard.Visibility = 'Visible'
    return $Content
}

function Add-HTToolbarRow {
    param([Parameter(Mandatory)][hashtable]$Module, [string]$Title = '')
    $wrap = New-Object System.Windows.Controls.WrapPanel
    $wrap.Orientation = 'Horizontal'
    $result = Add-HTParamRow -Module $Module -Title $Title -Content $wrap
    # Ostatni wiersz przycisków - tu trafiają przyciski akcji na zaznaczonych wierszach (Add-HTRowAction -Danger)
    $Module['LastToolbarRow'] = $wrap
    return $result
}

function Add-HTSeparator {
    param([Parameter(Mandatory)][hashtable]$Module)
    $b = New-Object System.Windows.Controls.Border
    $b.Height = 1
    $b.Background = Get-HTBrush '#242B36'
    $b.Margin = '0,8,0,6'
    [void]$Module.ParamsStack.Children.Add($b)
}

function Add-HTLabel {
    param([Parameter(Mandatory)]$Parent, [Parameter(Mandatory)][AllowEmptyString()][string]$Text, [switch]$Hint, [switch]$Bold, [double]$MaxWidth = 0)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.VerticalAlignment = 'Center'
    $t.Margin = '0,0,8,6'
    $t.TextWrapping = 'Wrap'
    if ($MaxWidth -gt 0) { $t.MaxWidth = $MaxWidth }
    if ($Hint) { $t.Foreground = Get-HTBrush '#7B8496'; $t.FontSize = 12 }
    if ($Bold) { $t.FontWeight = 'SemiBold' }
    [void]$Parent.Children.Add($t)
    return $t
}

function Add-HTTextBox {
    param([Parameter(Mandatory)]$Parent, [double]$Width = 200, [string]$Text = '', [string]$Placeholder = '', [switch]$Multiline, [double]$Height = 0)
    $tb = New-Object System.Windows.Controls.TextBox
    if ($Multiline) {
        $tb.Style = Get-HTThemeResource 'MultiText'
        $tb.FontFamily = 'Segoe UI'
        $tb.FontSize = 13
        $tb.TextWrapping = 'Wrap'
        $tb.Height = if ($Height -gt 0) { $Height } else { 90 }
    }
    $tb.Width = $Width
    $tb.Text = $Text
    if ($Placeholder) { $tb.Tag = $Placeholder }
    $tb.Margin = '0,0,8,6'
    [void]$Parent.Children.Add($tb)
    return $tb
}

function Add-HTComboBox {
    param([Parameter(Mandatory)]$Parent, [string[]]$Items = @(), [double]$Width = 180, [int]$Selected = 0, [switch]$Editable)
    $cb = New-Object System.Windows.Controls.ComboBox
    $cb.Width = $Width
    $cb.Margin = '0,0,8,6'
    if ($Editable) { $cb.IsEditable = $true }
    foreach ($i in $Items) { [void]$cb.Items.Add($i) }
    if ($cb.Items.Count -gt 0) { $cb.SelectedIndex = [Math]::Min([Math]::Max(0, $Selected), $cb.Items.Count - 1) }
    [void]$Parent.Children.Add($cb)
    return $cb
}

function Get-HTComboText($ComboBox) {
    if ($ComboBox.IsEditable) { return ([string]$ComboBox.Text).Trim() }
    return [string]$ComboBox.SelectedItem
}

$script:NumericSpecs = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:NumericEvents = @{
    PreviewTextInput = { param($s, $e) if ($e.Text -notmatch '^\d+$') { $e.Handled = $true } }
    LostFocus        = { param($s, $e) try { $s.Text = [string](Get-HTNum $s) } catch { Write-Verbose $_ } }
}

function Add-HTNumeric {
    param([Parameter(Mandatory)]$Parent, [int]$Value = 0, [int]$Minimum = 0, [int]$Maximum = 100000, [double]$Width = 80)
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Width = $Width
    $tb.Margin = '0,0,8,6'
    $tb.Text = [string]$Value
    $tb.HorizontalContentAlignment = 'Right'
    $script:NumericSpecs[$tb] = @{ Min = $Minimum; Max = $Maximum; Default = $Value }
    $tb.add_PreviewTextInput($script:NumericEvents.PreviewTextInput)
    $tb.add_LostFocus($script:NumericEvents.LostFocus)
    [void]$Parent.Children.Add($tb)
    return $tb
}

function Get-HTNum {
    param([Parameter(Mandatory)]$Control)
    $spec = $null
    if (-not $script:NumericSpecs.TryGetValue($Control, [ref]$spec)) { $spec = @{ Min = 0; Max = [int]::MaxValue; Default = 0 } }
    $v = 0
    if (-not [int]::TryParse(([string]$Control.Text).Trim(), [ref]$v)) { $v = $spec.Default }
    return [Math]::Min($spec.Max, [Math]::Max($spec.Min, $v))
}

function Add-HTCheckBox {
    param([Parameter(Mandatory)]$Parent, [Parameter(Mandatory)][string]$Text, [bool]$Checked = $false, [string]$ToolTip = '')
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $Text
    $cb.IsChecked = $Checked
    $cb.Margin = '2,0,16,6'
    if ($ToolTip) { $cb.ToolTip = $ToolTip }
    [void]$Parent.Children.Add($cb)
    return $cb
}

function Test-HTChecked($CheckBox) { return ($CheckBox.IsChecked -eq $true) }

$script:SegmentCounter = 0
function Add-HTSegmented {
    # Przełącznik segmentowy; indeks wyboru: Get-HTSegmentIndex
    param([AllowNull()]$Parent, [Parameter(Mandatory)][string[]]$Items, [int]$Selected = 0, [hashtable]$Module, [scriptblock]$OnChange)
    $script:SegmentCounter++
    $group = 'seg' + $script:SegmentCounter
    $container = New-Object System.Windows.Controls.Border
    $container.Style = Get-HTThemeResource 'SegmentHost'
    $container.Margin = '0,0,8,6'
    $container.HorizontalAlignment = 'Left'
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $container.Child = $sp
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $rb = New-Object System.Windows.Controls.RadioButton
        $rb.Style = Get-HTThemeResource 'SegmentRadio'
        $rb.GroupName = $group
        $rb.Content = $Items[$i]
        $rb.IsChecked = ($i -eq $Selected)
        if ($OnChange) { Register-HTControlHandler -Control $rb -EventName 'Checked' -Module $Module -Action $OnChange }
        [void]$sp.Children.Add($rb)
    }
    if ($Parent) { [void]$Parent.Children.Add($container) }
    return $container
}

function Get-HTSegmentIndex($Segmented) {
    $i = 0
    foreach ($rb in $Segmented.Child.Children) {
        if ($rb.IsChecked -eq $true) { return $i }
        $i++
    }
    return -1
}

function Add-HTButton {
    # Przycisk akcji modułu (wyłączany na czas operacji). Pierwszy -Primary jest domyślną akcją (F5).
    param(
        [Parameter(Mandatory)]$Parent,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][scriptblock]$OnClick,
        [string]$Icon = '',
        [string]$ToolTip = '',
        [switch]$Primary,
        [switch]$Danger,
        # Dodawanie / tworzenie (nowe konto, grupa, członkowie, uprawnienia, licencje): zmiana jak -Danger, ale zielona
        [switch]$Create,
        # Przycisk zmiany bez pozycji w menu wierszy wyników (nie działa na zaznaczonych wierszach, np. przywracanie z pliku)
        [switch]$NoRowMenu
    )
    $change = $Danger -or $Create
    $b = New-HTButton -Text $Text -Icon $Icon -Primary:$Primary -Danger:($Danger -and -not $Create) -Create:$Create -ToolTip $ToolTip
    $b.Margin = '0,0,8,6'
    Register-HTControlHandler -Control $b -EventName 'Click' -Module $Module -Action $OnClick
    [void]$Module.Buttons.Add($b)
    # F5 (główna akcja modułu) nigdy nie wykonuje zmiany - tylko odczyt (zasada trzech etapów)
    if ($Primary -and -not $change -and -not $Module.PrimaryButton) { $Module.PrimaryButton = $b }
    # Przyciski zmian (czerwone i zielone) są też w menu prawego przycisku na wierszach wyników (zaznaczone obiekty)
    if ($change -and -not $NoRowMenu) {
        if (-not $Module['ChangeButtons']) { $Module['ChangeButtons'] = New-Object System.Collections.Generic.List[hashtable] }
        $Module['ChangeButtons'].Add(@{ Button = $b; Text = $Text; Icon = $Icon; Create = [bool]$Create })
    }
    [void]$Parent.Children.Add($b)
    return $b
}

function Add-HTStateCheck {
    <#
        Etap 2 zasady trzech etapów: niebieski przycisk «Sprawdź stan» (F5) w pierwszym wierszu modułu - bieżący stan
        obiektów zaznaczonych na liście po lewej. Zmiany (czerwone przyciski) działają potem na wierszach zaznaczonych
        w wynikach. -Action { param($t) } zwraca wiersz stanu obiektu. Wywołać na początku bloku -Build modułu.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][scriptblock]$Action,
        [scriptblock]$Label,
        [string]$Text = 'Sprawdź stan',
        [string]$Hint = 'Najpierw sprawdź stan, potem zaznacz wiersze w wynikach - zmiany (czerwone przyciski) obejmą tylko je.'
    )
    $Module.Data.StateCheck = @{ Action = $Action; Label = $Label; Text = $Text }
    $row = Add-HTToolbarRow -Module $Module -Title 'Stan'
    [void](Add-HTButton -Parent $row -Module $Module -Text $Text -Icon 'E946' -Primary -OnClick {
            param($m)
            $check = $m.Data.StateCheck
            Invoke-HTTargetQuery -Module $m -Name "$($check.Text) - $($m.Title)" -AlwaysShowObject -Label $check.Label -Action $check.Action
        })
    if ($Hint) { [void](Add-HTLabel -Parent $row -Hint -Text $Hint) }
    return $row
}

function Add-HTRowAction {
    <#
        Akcja w menu kontekstowym tabeli wyników: { param($m, $rows) } - $rows to zaznaczone obiekty wyników.
        -Danger (zmiana): czerwona pozycja menu z liczbą zaznaczonych wierszy i czerwony przycisk u góry modułu
        (w ostatnim wierszu przycisków) działający na wierszach zaznaczonych w wynikach. -NoButton: tylko w menu.
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][scriptblock]$Action, [string]$Icon = 'E76C', [switch]$Danger, [switch]$Create, [switch]$NoButton)
    # -Create: dodawanie / tworzenie (zielone) - zachowanie jak -Danger (liczba zaznaczonych, przycisk u góry)
    if ($Create) { $Danger = $true }
    $entry = @{ Text = $Text; Action = $Action; Icon = $Icon; Danger = [bool]$Danger; Create = [bool]$Create }
    [void]$Module.RowActions.Add($entry)
    if (-not $Danger -or $NoButton) { return }
    <#
        Układ: dodawanie (zielone) w ostatnim wierszu przycisków obok odczytu; zmiany (czerwone) w osobnym wierszu na dole
        panelu - usuwanie / odbieranie na końcu wiersza.
    #>
    if ($Create) {
        $parent = $Module['LastToolbarRow']
        if (-not $parent) { $parent = Add-HTToolbarRow -Module $Module; $parent = $Module['LastToolbarRow'] }
    }
    else {
        $parent = $Module['ChangeRow']
        if (-not $parent) {
            $parent = New-Object System.Windows.Controls.WrapPanel
            $parent.Orientation = 'Horizontal'
            [void](Add-HTParamRow -Module $Module -Content $parent)
            $Module['ChangeRow'] = $parent
            $Module['ChangeRowContainer'] = $parent.Parent
        }
    }
    $b = New-HTButton -Text $Text -Icon $Icon -Danger:(-not $Create) -Create:$Create -ToolTip "$($Text.TrimEnd('…')) - na wierszach zaznaczonych w wynikach (także prawy przycisk na wierszach)"
    $b.Margin = '0,0,8,6'
    $b.Tag = $entry
    Register-HTControlHandler -Control $b -EventName 'Click' -Module $Module -Action {
        param($m, $s)
        $rows = @(Get-HTResultSelection -Module $m)
        if ($rows.Count -eq 0) { Show-HTWarning 'Najpierw pobierz wyniki (niebieski przycisk) i zaznacz w tabeli wiersze, których dotyczy zmiana.' -Title 'Zaznacz wiersze'; return }
        $null = & $s.Tag.Action $m $rows
    }
    [void]$Module.Buttons.Add($b)
    $entry.Button = $b
    # Za ostatnim przyciskiem wiersza (przed podpowiedziami); w wierszu zmian usuwanie zawsze na końcu
    $removal = { param($t) [string]$t -match '^(Usuń|Odbierz|Wyczyść)' }
    $index = 0
    for ($i = 0; $i -lt $parent.Children.Count; $i++) {
        $child = $parent.Children[$i]
        if ($child -isnot [System.Windows.Controls.Button]) { continue }
        if (-not $Create -and -not (& $removal $Text) -and $child.Tag -is [hashtable] -and (& $removal $child.Tag.Text)) { break }
        $index = $i + 1
    }
    $parent.Children.Insert($index, $b)
}

#region Akcje na obiektach w wynikach (np. blokada konta z raportu nieaktywnych użytkowników)
<#
    Rodzaj obiektu rozpoznawany w wierszach wyników dowolnego modułu: -Resolve { param($row) } zwraca identyfikator
    (np. UPN) albo $null. Akcje rodzaju (Register-HTObjectAction) są w podmenu «<Tytuł> (N)» menu prawego przycisku.
    -Workspaces: tylko w tych przestrzeniach (puste - wszędzie).
#>
$script:ObjectKinds = New-Object System.Collections.Generic.List[hashtable]

function Register-HTObjectKind {
    param([Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Title, [string]$Icon = 'E77B', [Parameter(Mandatory)][scriptblock]$Resolve, [string]$Service = '', [string[]]$Workspaces = @())
    $existing = @($script:ObjectKinds | Where-Object { $_.Kind -eq $Kind })[0]
    if ($existing) { [void]$script:ObjectKinds.Remove($existing) }
    $script:ObjectKinds.Add(@{ Kind = $Kind; Title = $Title; Icon = $Icon; Resolve = $Resolve; Service = $Service; Workspaces = @($Workspaces); Actions = (New-Object System.Collections.Generic.List[hashtable]) })
}

function Register-HTObjectAction {
    <#
        Akcja rodzaju obiektu: -Action { param($Id, $Row) } zwraca opis wyniku. Zmiany: -Danger (czerwone) i -Confirm
        (pytanie z listą obiektów). -View: podgląd jednego obiektu (bez potwierdzenia i historii operacji).
    #>
    param([Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Text, [string]$Icon = 'E76C', [Parameter(Mandatory)][scriptblock]$Action, [switch]$Danger, [string]$Confirm = '', [string]$Name = '', [switch]$View)
    $definition = @($script:ObjectKinds | Where-Object { $_.Kind -eq $Kind })[0]
    if (-not $definition) { throw "Nieznany rodzaj obiektu: $Kind" }
    $definition.Actions.Add(@{ Text = $Text; Icon = $Icon; Action = $Action; Danger = [bool]$Danger; Confirm = $Confirm; Name = $(if ($Name) { $Name } else { $Text.TrimEnd('…') }); View = [bool]$View })
}

function Get-HTObjectActionTargets {
    # Rozpoznane obiekty zaznaczonych wierszy: @{ Id; Row; Label }, bez powtórzeń identyfikatora
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][hashtable]$Kind)
    $seen = @{}
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($row in @(Get-HTResultSelection -Module $Module)) {
        if (-not $row) { continue }
        $id = $null
        try { $id = [string](& $Kind.Resolve $row) } catch { $id = $null }
        if (-not $id -or $seen.ContainsKey($id.ToLowerInvariant())) { continue }
        $seen[$id.ToLowerInvariant()] = $true
        $list.Add([PSCustomObject]@{ Id = $id; Row = $row; Label = $id })
    }
    return $list.ToArray()
}

function Get-HTObjectActionMenus {
    # Podmenu akcji dla rodzajów obiektów rozpoznanych w zaznaczonych wierszach
    param([Parameter(Mandatory)][hashtable]$Module)
    foreach ($kind in $script:ObjectKinds) {
        if ($kind.Actions.Count -eq 0) { continue }
        if ($kind.Workspaces.Count -and $kind.Workspaces -notcontains [string]$Module.Workspace) { continue }
        $targets = @(Get-HTObjectActionTargets -Module $Module -Kind $kind)
        if ($targets.Count -eq 0) { continue }
        $parent = New-HTMenuItem -Text "$($kind.Title) ($($targets.Count))" -Icon $kind.Icon -Module $Module
        foreach ($a in $kind.Actions) {
            $enabled = -not $a.View -or $targets.Count -ge 1
            [void]$parent.Items.Add((New-HTMenuItem -Text $a.Text -Icon $a.Icon -Danger:$a.Danger -Module $Module -Enabled $enabled -Data @{ Kind = $kind; Definition = $a } -Action {
                        param($m, $s)
                        Invoke-HTObjectAction -Module $m -Kind $s.Tag.Data.Kind -Definition $s.Tag.Data.Definition
                    }))
        }
        $parent
    }
}

function Invoke-HTObjectAction {
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][hashtable]$Kind, [Parameter(Mandatory)][hashtable]$Definition)
    $targets = @(Get-HTObjectActionTargets -Module $Module -Kind $Kind)
    if ($targets.Count -eq 0) { Show-HTWarning 'Zaznacz wiersze z obiektami w tabeli wyników.'; return }
    if ($Kind.Service -and -not (Assert-HTConnection -Service $Kind.Service)) { return }
    if ($Definition.View) {
        $first = $targets[0]
        $null = & $Definition.Action $first.Id $first.Row
        return
    }
    # Blok akcji i identyfikator przekazane w obiekcie (bez odwołań do zmiennych tej funkcji z wnętrza bloku)
    $items = @($targets | ForEach-Object { [PSCustomObject]@{ Id = $_.Id; Row = $_.Row; Label = $_.Label; Run = $Definition.Action } })
    Invoke-HTRowAction -Module $Module -Name $Definition.Name -Rows $items -Danger:$Definition.Danger -Confirm $Definition.Confirm -Service $Kind.Service `
        -Label { param($r) $r.Label } -Action { param($r) & $r.Run $r.Id $r.Row }
}
#endregion

function Update-HTGridMenu {
    # Menu kontekstowe budowane przy otwarciu: nagłówek - menu kolumny; wiersze - akcje modułu, kopiowanie, eksport, szybki filtr
    param([hashtable]$Module)
    $menu = $Module.Grid.ContextMenu
    $menu.Items.Clear()
    if ($Module.MenuCell -and $Module.MenuCell.Header) { Update-HTHeaderMenu -Module $Module -Menu $menu -Column $Module.MenuCell.Column; return }
    $selected = @($Module.Grid.SelectedItems | Where-Object { $_ -is [System.Data.DataRowView] })
    $hasRows = $selected.Count -gt 0
    foreach ($a in $Module.RowActions) {
        # Akcja dostaje oryginalne obiekty zaznaczonych wierszy: { param($m, $rows) }; zmiany - z liczbą zaznaczonych
        $text = if ($a.Danger -and $hasRows) { "$($a.Text) - zaznaczone ($($selected.Count))" } else { $a.Text }
        [void]$menu.Items.Add((New-HTMenuItem -Text $text -Icon $a.Icon -Module $Module -Danger:$a.Danger -Create:([bool]$a['Create']) -Enabled $hasRows -Data $a.Action -Action {
                    param($m, $s)
                    $rows = @(Get-HTResultSelection -Module $m)
                    if ($rows.Count -eq 0) { Show-HTWarning 'Zaznacz wiersze w tabeli wyników.'; return }
                    $null = & $s.Tag.Data $m $rows
                }))
    }
    # Zmiany modułu (czerwone przyciski) dla obiektów z zaznaczonych wierszy (wyniki «Sprawdź stan» / «Pokaż…»)
    $rowTargets = if ($hasRows) { @(Get-HTSelectedResultTargets -Module $Module) } else { @() }
    if ($rowTargets.Count -and $Module['ChangeButtons']) {
        foreach ($cb in @($Module['ChangeButtons'] | Where-Object { $_ -and $_.Button.IsEnabled -and $_.Button.IsVisible })) {
            [void]$menu.Items.Add((New-HTMenuItem -Text "$($cb.Text) - zaznaczone ($($rowTargets.Count))" -Icon $cb.Icon -Danger:(-not $cb['Create']) -Create:([bool]$cb['Create']) -Module $Module -Data $cb.Button -Action {
                        param($m, $s)
                        $button = $s.Tag.Data
                        $button.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $button)))
                    }))
        }
    }
    # Akcje na rozpoznanych obiektach (konto, skrzynka, urządzenie) - z dowolnego raportu i wyniku
    if ($hasRows) { foreach ($objectMenu in @(Get-HTObjectActionMenus -Module $Module)) { [void]$menu.Items.Add($objectMenu) } }
    if ($menu.Items.Count -gt 0) { [void]$menu.Items.Add((New-HTMenuSeparator)) }
    [void]$menu.Items.Add((New-HTMenuItem -Text 'Szczegóły wiersza' -Icon 'E8A1' -Module $Module -Enabled $hasRows -Action {
                param($m)
                if ($m.Grid.SelectedItem) { Show-HTRowDetails -Module $m -Row $m.Grid.SelectedItem }
            }))
    [void]$menu.Items.Add((New-HTMenuItem -Text 'Kopiuj wartość komórki' -Icon 'E8C8' -Module $Module -Enabled ($hasRows -or [bool]$Module.MenuCell) -Action {
                param($m)
                $row = $null
                $name = ''
                if ($m.MenuCell -and $m.MenuCell.Row) { $row = $m.MenuCell.Row; $name = [string]$m.MenuCell.Column }
                else {
                    $cell = $m.Grid.CurrentCell
                    if ($cell.Column -and $cell.Item -is [System.Data.DataRowView]) { $row = $cell.Item; $name = [string]$cell.Column.SortMemberPath }
                }
                if (-not $row) { return }
                Set-HTClipboard ([string](Get-HTExportValue -Module $m -Row $row -Column $name)) -Secret:($m.RevealSecrets -and $m.SecretColumns -contains $name)
                Show-HTToast "Skopiowano: $name" 'ok' 2
            }))
    if ($Module.MenuCell -and $Module.MenuCell.Column -and $null -ne $Module.View) {
        # Wartości jednej kolumny (np. adresy do «Zaznacz z listy»): zaznaczone wiersze albo wszystkie widoczne
        $colName = [string]$Module.MenuCell.Column
        if ($selected.Count -gt 1) {
            [void]$menu.Items.Add((New-HTMenuItem -Text ("Kopiuj kolumnę «{0}» - zaznaczone wiersze ({1})" -f $colName, $selected.Count) -Icon 'E8C8' -Module $Module -Action { param($m) Copy-HTColumnValues -Module $m -Column $m.MenuCell.Column -SelectedOnly }))
        }
        [void]$menu.Items.Add((New-HTMenuItem -Text ("Kopiuj kolumnę «{0}» - wszystkie widoczne ({1})" -f $colName, $Module.View.Count) -Icon 'E8C8' -Module $Module -Action { param($m) Copy-HTColumnValues -Module $m -Column $m.MenuCell.Column }))
    }
    [void]$menu.Items.Add((New-HTMenuItem -Text 'Kopiuj zaznaczone wiersze' -Icon 'E8C8' -Module $Module -Enabled $hasRows -Action { param($m) Copy-HTResultView -Module $m -SelectedOnly }))
    [void]$menu.Items.Add((New-HTMenuItem -Text 'Eksport…' -Icon 'EDE1' -Module $Module -Action { param($m) Export-HTResultView -Module $m }))
    if ($Module.MenuCell -or $Module.ColumnFilters.Count -gt 0) {
        [void]$menu.Items.Add((New-HTMenuSeparator))
        if ($Module.MenuCell) { Add-HTQuickFilterMenu -Module $Module -Menu $menu }
        elseif ($Module.ColumnFilters.Count -gt 0) { [void]$menu.Items.Add((New-HTMenuItem -Text 'Wyczyść filtry kolumn' -Icon 'E894' -Module $Module -Action { param($m) Clear-HTColumnFilters -Module $m })) }
    }
}

function Add-HTStatTile {
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Label, [string]$Icon = '', [string]$Value = '–')
    $xaml = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Padding="14,10" Margin="0,0,10,0">
  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <Border Width="34" Height="34" CornerRadius="8" Background="#1B2333" Margin="0,0,12,0" VerticalAlignment="Center">
      <TextBlock Name="icon" Style="{StaticResource Glyph}" FontSize="15" Foreground="#8CB0FF" HorizontalAlignment="Center"/>
    </Border>
    <StackPanel Grid.Column="1" VerticalAlignment="Center">
      <TextBlock Name="value" FontSize="20" FontWeight="SemiBold" Foreground="White"/>
      <TextBlock Name="label" FontSize="11.5" Foreground="#8791A5" TextTrimming="CharacterEllipsis"/>
    </StackPanel>
  </Grid>
</Border>
"@
    $tile = New-HTUiElement $xaml
    $tile.Style = Get-HTThemeResource 'Card'
    $tile.Padding = '14,10'
    $tile.FindName('icon').Text = Get-HTGlyph $(if ($Icon) { $Icon } else { 'E9D2' })
    $tile.FindName('value').Text = $Value
    $tile.FindName('label').Text = $Label
    $Module.Stats[$Key] = $tile
    [void]$Module.StatsGrid.Children.Add($tile)
    $Module.StatsGrid.Columns = $Module.StatsGrid.Children.Count
    $Module.StatsGrid.Visibility = 'Visible'
    return $tile
}

function Set-HTStatTile {
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Key, [string]$Value = '–', [ValidateSet('', 'ok', 'warn', 'crit', 'info', 'off')][string]$Tone = '', [string]$Label = '')
    $tile = $Module.Stats[$Key]
    if (-not $tile) { return }
    $v = $tile.FindName('value')
    $v.Text = $Value
    $v.Foreground = Get-HTBrush $(switch ($Tone) { 'ok' { '#5EE3AE' } 'warn' { '#FFC46B' } 'crit' { '#FF7A86' } 'info' { '#8CC0FF' } 'off' { '#5E6779' } default { '#FFFFFF' } })
    if ($Label) { $tile.FindName('label').Text = $Label }
}

function Reset-HTResults {
    # Czyści tabelę wyników (nowe wyniki - nowe kolumny)
    param([Parameter(Mandatory)][hashtable]$Module)
    $table = New-Object System.Data.DataTable 'Wyniki'
    foreach ($c in '__search', '__flag', '__cf') { [void]$table.Columns.Add($c, [string]) }
    [void]$table.Columns.Add('__obj', [object])
    # Nowe wyniki - nowe kolumny: filtry kolumn i ich lejki od zera (pole «Filtruj wyniki» i ukryte kolumny zostają)
    if ($null -ne $Module.ColumnFilters) { $Module.ColumnFilters.Clear() }
    $Module.FilterButtons = @{}
    if ($Module.View_ -and $Module.View_['btnFilters']) { $Module.View_['btnFilters'].Visibility = 'Collapsed' }
    $view = [System.Data.DataView]::new($table)
    $Module.Table = $table
    $Module.View = $view
    $Module.ColumnIndex = @{}
    $Module.Objects.Clear()
    $g = $Module.Grid
    if ($g) {
        $g.ItemsSource = $null
        $g.Columns.Clear()
        $g.ItemsSource = $view
    }
    Update-HTResultFilter -Module $Module
}

function Add-HTGridColumn {
    param([hashtable]$Module, [string]$Name)
    $g = $Module.Grid
    if (-not $g -or $Module.ColumnIndex.ContainsKey($Name)) { return }
    $Module.ColumnIndex[$Name] = $true
    if ($Name.StartsWith('__') -or $Module.HiddenColumns -contains $Name) { return }
    $col = New-Object System.Windows.Controls.DataGridTextColumn
    $col.Binding = New-Object System.Windows.Data.Binding ('[' + $Name + ']')
    $style = New-Object System.Windows.Style ([System.Windows.Controls.TextBlock])
    $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::TextTrimmingProperty, [System.Windows.TextTrimming]::CharacterEllipsis)))
    $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.FrameworkElement]::MaxHeightProperty, [double]18)))
    $col.ElementStyle = $style
    if ($Module.GoodWhenNo -contains $Name) { $col.CellStyle = Get-HTThemeResource 'BoolCellInv' }
    elseif ($Module.ColorBools) { $col.CellStyle = Get-HTThemeResource 'BoolCell' }
    # Nagłówek: nazwa i lejek filtra (bez filtra dla wartości poufnych)
    $col.Header = New-HTColumnHeader -Module $Module -Name $Name -NoFilter:($Module.SecretColumns -contains $Name)
    $col.SortMemberPath = $Name
    $col.IsReadOnly = $true
    $col.MaxWidth = 520
    $col.MinWidth = 54
    $g.Columns.Add($col)
    if ($Module.UserHidden -and $Module.UserHidden.Contains($Name)) {
        $col.Visibility = 'Collapsed'
        Update-HTColumnsButton -Module $Module
    }
}

function Add-HTResultRows {
    <#
        Dodaje obiekty jako wiersze tabeli modułu; nowe właściwości tworzą nowe kolumny.
        Właściwość __flag (crit/warn/muted) koloruje wiersz. Oryginalny obiekt zostaje zapamiętany
        (Get-HTResultSelection zwraca go dla zaznaczonych wierszy).
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [AllowEmptyCollection()][object[]]$Objects)
    $table = $Module.Table
    if ($null -eq $table) { return }
    $table.BeginLoadData()
    try {
        foreach ($obj in $Objects) {
            if ($null -eq $obj) { continue }
            $values = New-Object System.Collections.Specialized.OrderedDictionary
            $base = if ($obj -is [System.Management.Automation.PSObject]) { $obj.PSObject.BaseObject } else { $obj }
            # Właściwości z prefiksem __ (poza __flag) są pomocnicze - zostają tylko w obiekcie wiersza (__obj)
            if ($base -is [string] -or $base -is [System.ValueType]) { $values['Wynik'] = ConvertTo-HTCellValue $base }
            elseif ($base -is [System.Collections.IDictionary]) {
                foreach ($k in $base.Keys) {
                    $name = [string]$k
                    if ($name -eq '__flag') { $values[$name] = [string]$base[$k] }
                    elseif (-not $name.StartsWith('__')) { $values[$name] = ConvertTo-HTCellValue $base[$k] }
                }
            }
            else {
                foreach ($p in $obj.PSObject.Properties) {
                    if ($p.Name -eq '__flag') { $values[$p.Name] = [string]$p.Value }
                    elseif (-not $p.Name.StartsWith('__')) { $values[$p.Name] = ConvertTo-HTCellValue $p.Value }
                }
            }
            foreach ($name in @($values.Keys)) {
                if (-not $table.Columns.Contains($name)) { [void]$table.Columns.Add($name, [object]) }
                if ($Module.SecretColumns -contains $name -and -not $table.Columns.Contains("__secret_$name")) { [void]$table.Columns.Add("__secret_$name", [object]) }
                Add-HTGridColumn -Module $Module -Name $name
            }
            $row = $table.NewRow()
            $search = New-Object System.Text.StringBuilder
            foreach ($name in $values.Keys) {
                $v = $values[$name]
                if ($Module.SecretColumns -contains $name) {
                    $row["__secret_$name"] = $v
                    if (-not $Module.RevealSecrets -and $v -isnot [System.DBNull] -and [string]$v -ne '') { $v = '••••••••••' }
                    $row[$name] = $v
                    continue
                }
                $row[$name] = $v
                if ($v -isnot [System.DBNull] -and -not $name.StartsWith('__')) { [void]$search.Append([string]$v).Append(' ') }
            }
            $row['__search'] = $search.ToString().ToLowerInvariant()
            $row['__obj'] = $obj
            if ($Module.ColumnFilters.Count -gt 0) { $row['__cf'] = $(if (Test-HTRowColumnFilters -Module $Module -Row $row) { '1' } else { '0' }) }
            if (-not $values.Contains('__flag')) {
                $status = [string]$values['Status']
                if ($status.StartsWith('Błąd')) { $row['__flag'] = 'crit' }
                elseif ($status.StartsWith('Pominięto') -or $status.StartsWith('Test')) { $row['__flag'] = 'muted' }
            }
            $table.Rows.Add($row)
        }
    }
    finally { $table.EndLoadData() }
    Update-HTResultCount -Module $Module
    Update-HTUi
}

function Get-HTResultSelection {
    # Oryginalne obiekty zaznaczonych wierszy tabeli wyników
    param([Parameter(Mandatory)][hashtable]$Module, [switch]$AllVisible)
    $rows = if ($AllVisible) { @($Module.View | ForEach-Object { $_ }) } else { @($Module.Grid.SelectedItems) }
    foreach ($drv in $rows) {
        if ($drv -is [System.Data.DataRowView]) {
            $o = $drv.Row['__obj']
            if ($o -isnot [System.DBNull]) { $o }
        }
    }
}

function Set-HTSecretReveal {
    param([hashtable]$Module, [bool]$Reveal)
    $Module.RevealSecrets = $Reveal
    foreach ($row in $Module.Table.Rows) {
        foreach ($name in $Module.SecretColumns) {
            if (-not $Module.Table.Columns.Contains($name)) { continue }
            $real = $row["__secret_$name"]
            $row[$name] = if ($Reveal -or $real -is [System.DBNull] -or [string]$real -eq '') { $real } else { '••••••••••' }
        }
    }
}

function Request-HTResultFilter {
    # Filtr z opóźnieniem (wpisywanie nie przelicza tabeli przy każdym znaku)
    param([hashtable]$Module)
    if (-not $script:FilterTimer) {
        $script:FilterTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:FilterTimer.Interval = [TimeSpan]::FromMilliseconds(220)
        $script:FilterTimer.add_Tick({
                param($s, $e)
                $s.Stop()
                $m = $script:FilterPending
                $script:FilterPending = $null
                if ($m) { Update-HTResultFilter -Module $m }
            })
    }
    if ($script:FilterPending -and -not [object]::ReferenceEquals($script:FilterPending, $Module)) { Update-HTResultFilter -Module $script:FilterPending }
    $script:FilterPending = $Module
    $script:FilterTimer.Stop()
    $script:FilterTimer.Start()
}

function Update-HTResultFilter {
    param([hashtable]$Module)
    if ($null -eq $Module.View) { return }
    $text = if ($Module.FilterBox) { $Module.FilterBox.Text } else { '' }
    $extra = if ($Module.ColumnFilters.Count -gt 0) { @("[__cf] = '1'") } else { @() }
    Set-HTViewFilter -View $Module.View -Text $text -Extra $extra
    Update-HTResultCount -Module $Module
    Update-HTViewsButton -Module $Module
}

function Update-HTResultCount {
    param([hashtable]$Module)
    if ($null -eq $Module.View -or -not $Module.View_) { return }
    $total = $Module.Table.Rows.Count
    $visible = $Module.View.Count
    $g = $Module.Grid
    if ($g) { $g.HeadersVisibility = if ($g.Columns.Count -gt 0) { 'Column' } else { 'None' } }
    $count = $Module.View_['countText']
    if ($count) { $count.Text = if ($visible -eq $total) { [string]$total } else { "$visible z $total" } }
    $empty = $Module.View_['emptyState']
    if ($empty) {
        if ($visible -gt 0) { $empty.Visibility = 'Collapsed' }
        else {
            $empty.Visibility = 'Visible'
            if ($total -gt 0) {
                $Module.View_['emptyText'].Text = 'Nic nie pasuje do filtra'
                $Module.View_['emptyHint'].Text = 'Zmień lub wyczyść filtr. Słowo poprzedzone minusem wyklucza wiersze.'
            }
            else {
                $Module.View_['emptyText'].Text = $(if ($Module.EmptyText) { $Module.EmptyText } else { 'Brak wyników' })
                $Module.View_['emptyHint'].Text = [string]$Module.EmptyHint
            }
        }
    }
}

function Set-HTToggleButtonState {
    <#
        Przełącznik na pasku nad tabelą (widok, puste kolumny, kolumny, panel szczegółów): włączony - podświetlony
        jak chip filtrów kolumn, z dopiskiem w podpowiedzi. Wyłączony - wygląd zwykłego przycisku.
    #>
    param($Button, [bool]$Active, [string]$ToolTip = '')
    if (-not $Button) { return }
    if ($Active) {
        $Button.Background = Get-HTBrush '#1A2640'
        $Button.BorderBrush = Get-HTBrush '#3E6FE0'
        $Button.Foreground = Get-HTBrush '#8CB0FF'
    }
    else {
        foreach ($dp in [System.Windows.Controls.Control]::BackgroundProperty, [System.Windows.Controls.Control]::BorderBrushProperty, [System.Windows.Controls.Control]::ForegroundProperty) { $Button.ClearValue($dp) }
    }
    $Button.Tag = $(if ($Active) { 'on' } else { $null })
    if ($ToolTip) { $Button.ToolTip = $ToolTip }
}

function Get-HTViewSignature {
    # Bieżący stan widoku modułu (filtr tekstowy, filtry kolumn, ukryte kolumny) jako tekst do porównania z zapisanym widokiem
    param([hashtable]$Module)
    $text = if ($Module.FilterBox) { [string]$Module.FilterBox.Text } else { '' }
    $preset = ConvertTo-HTFilterPreset -Name 'bieżący' -Text $text.Trim() -ColumnFilters $Module.ColumnFilters -Hidden @($Module.UserHidden)
    $filters = @($preset.Filters | Sort-Object { $_.Column } | ForEach-Object { [ordered]@{ Column = $_.Column; Values = @($_.Values | Sort-Object); Op = $_.Op; Text = $_.Text } })
    return ([ordered]@{ Text = $preset.Text; Filters = $filters; Hidden = @($preset.Hidden | Sort-Object) } | ConvertTo-Json -Compress -Depth 5)
}

function Update-HTViewsButton {
    # Przycisk «Zapisane widoki»: podświetlony z nazwą widoku, dopóki widok nie zostanie zmieniony ręcznie
    param([hashtable]$Module)
    $b = if ($Module.View_) { $Module.View_['btnViews'] } else { $null }
    if (-not $b) { return }
    $active = $Module['ActiveView']
    if ($active -and $active.Signature -ne (Get-HTViewSignature -Module $Module)) { $Module['ActiveView'] = $null; $active = $null }
    $b.Content = New-HTIconContent -Text $(if ($active) { [string]$active.Name } else { '' }) -Icon 'E71D'
    Set-HTToggleButtonState -Button $b -Active ([bool]$active) -ToolTip $(if ($active) { "Widok «$($active.Name)» - zmiana filtra albo kolumn kończy widok. Kliknij: zapisane widoki." } else { 'Zapisane widoki: filtr, filtry kolumn i ukryte kolumny tego modułu' })
}

function Update-HTDetailPane {
    param([hashtable]$Module)
    $v = $Module.View_
    if (-not $v -or -not $v['detailPane']) { return }
    Set-HTToggleButtonState -Button $v['btnDetail'] -Active ([bool]$script:UI.DetailVisible) -ToolTip $(if ($script:UI.DetailVisible) { 'Panel szczegółów wiersza - włączony (kliknij, aby ukryć)' } else { 'Panel szczegółów wiersza (kliknij, aby pokazać)' })
    if ($script:UI.DetailVisible) {
        $v.detailPane.Visibility = 'Visible'
        $v.detailSplit.Visibility = 'Visible'
        if ($v.detailCol.Width.Value -lt 120) { $v.detailCol.Width = New-Object System.Windows.GridLength 340 }
    }
    else {
        $v.detailPane.Visibility = 'Collapsed'
        $v.detailSplit.Visibility = 'Collapsed'
        $v.detailCol.Width = New-Object System.Windows.GridLength 0
    }
}

function Get-HTExportValue {
    # Wartość komórki do kopiowania i eksportu (wartości poufne - prawdziwe tylko po «Pokaż poufne»)
    param([hashtable]$Module, $Row, [string]$Column)
    if ($Module.SecretColumns -contains $Column -and $Module.RevealSecrets) { return Get-HTObjectValue $Row "__secret_$Column" }
    return Get-HTObjectValue $Row $Column
}

function Get-HTVisibleColumnNames {
    # Kolumny w kolejności z tabeli, bez ukrytych (kopiowanie i eksport)
    param([hashtable]$Module)
    return @($Module.Grid.Columns | Where-Object { $_.Visibility -eq 'Visible' } | Sort-Object DisplayIndex | ForEach-Object { [string]$_.SortMemberPath })
}

function Format-HTRowDetails {
    param([hashtable]$Module, $Row)
    $sb = New-Object System.Text.StringBuilder
    foreach ($col in $Module.Table.Columns) {
        $name = $col.ColumnName
        if ($name.StartsWith('__')) { continue }
        $v = Get-HTExportValue -Module $Module -Row $Row -Column $name
        if ([string]$v -eq '') { continue }
        $text = [string]$v
        if ($text -match "[\r\n]") { [void]$sb.AppendLine("${name}:").AppendLine($text.Trim()).AppendLine() }
        else { [void]$sb.AppendLine(('{0}:  {1}' -f $name, $text)) }
    }
    return $sb.ToString()
}

function Update-HTDetailText {
    param([hashtable]$Module)
    $box = $Module.View_['detailText']
    if (-not $box) { return }
    $item = $Module.Grid.SelectedItem
    $box.Text = if ($item -is [System.Data.DataRowView]) { Format-HTRowDetails -Module $Module -Row $item } else { '' }
}

# Pola z treścią (wiadomości, komunikaty, opisy) - zawsze osobna, wyróżniona sekcja na końcu okna szczegółów
$script:RowDetailBodyPattern = '^(Treść|Komunikat|Opis|Wiadomość|Body|Message|Content|Description|Szczegóły)$'

function Get-HTRowDetailFields {
    # Pola wiersza do okna szczegółów: Short - krótkie (etykieta: wartość), Long - wielowierszowe lub długie (osobne sekcje)
    param([hashtable]$Module, $Row)
    $short = New-Object System.Collections.Generic.List[object]
    $long = New-Object System.Collections.Generic.List[object]
    foreach ($col in $Module.Table.Columns) {
        $name = $col.ColumnName
        if ($name.StartsWith('__')) { continue }
        $text = [string](Get-HTExportValue -Module $Module -Row $Row -Column $name)
        if ($text -eq '') { continue }
        $field = [PSCustomObject]@{ Name = $name; Text = $text.Trim(); Body = ($name -match $script:RowDetailBodyPattern) }
        if ($field.Body -or $text -match "[\r\n]" -or $text.Length -gt 160) { $long.Add($field) } else { $short.Add($field) }
    }
    # Treść na końcu (najważniejsza - wyróżniona), pozostałe długie pola w kolejności kolumn
    $ordered = @(@($long | Where-Object { -not $_.Body }) + @($long | Where-Object { $_.Body }))
    return [PSCustomObject]@{ Short = $short.ToArray(); Long = $ordered }
}

function Show-HTRowDetails {
    # Szczegóły wiersza: krótkie pola w siatce, długie (np. treść wiadomości) w osobnych sekcjach z zawijaniem wierszy
    param([hashtable]$Module, $Row)
    if (-not ($Row -is [System.Data.DataRowView])) { return }
    $title = 'Szczegóły'
    foreach ($c in 'Obiekt', 'Nazwa', 'Tytuł', 'Użytkownik', 'Skrzynka', 'Urządzenie', 'Name') {
        $v = Get-HTObjectValue $Row $c
        if ($v) { $title = "Szczegóły - $v"; break }
    }
    $fields = Get-HTRowDetailFields -Module $Module -Row $Row
    $body = '<ScrollViewer x:Name="rdScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel x:Name="rdHost" Margin="0,0,10,0"/></ScrollViewer>'
    $w = New-HTDialog -Title $title -Subtitle $Module.Title -Body $body -Icon 'E8A5' -OkText 'Zamknij' -NoCancel -Width 920 -Height 680 -Resizable
    $hostPanel = $w.FindName('rdHost')
    $newValueBox = {
        param([string]$Text, [double]$Size, [string]$Color)
        $box = New-Object System.Windows.Controls.TextBox
        $box.Text = ($Text -replace "`r?`n", "`r`n")
        $box.IsReadOnly = $true
        $box.TextWrapping = 'Wrap'
        $box.BorderThickness = 0
        $box.Background = [System.Windows.Media.Brushes]::Transparent
        $box.Foreground = Get-HTBrush $Color
        $box.FontSize = $Size
        $box.Padding = '0'
        $box.Margin = '0'
        # Styl pola tekstowego ma wysokość min. 30 i tekst wyśrodkowany - w tabeli tekst od góry, równo z etykietą
        $box.MinHeight = 0
        $box.VerticalContentAlignment = 'Top'
        $box.VerticalAlignment = 'Top'
        [System.Windows.Controls.TextBlock]::SetLineHeight($box, [Math]::Round($Size * 1.45))
        return $box
    }
    if ($fields.Short.Count) {
        # Tabela: kolumna nazw pól, linie między wierszami i naprzemienne tło - widać, gdzie kończy się każda wartość
        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition
        $c1.Width = [System.Windows.GridLength]::Auto
        $c1.MaxWidth = 260
        [void]$grid.ColumnDefinitions.Add($c1)
        [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
        $r = 0
        foreach ($f in $fields.Short) {
            [void]$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
            $last = ($r -eq $fields.Short.Count - 1)
            $band = New-Object System.Windows.Controls.Border
            $band.Background = Get-HTBrush $(if ($r % 2) { '#151B24' } else { '#11161D' })
            $band.BorderBrush = Get-HTBrush '#232A36'
            $band.BorderThickness = $(if ($last) { '0' } else { '0,0,0,1' })
            [System.Windows.Controls.Grid]::SetRow($band, $r)
            [System.Windows.Controls.Grid]::SetColumnSpan($band, 2)
            [void]$grid.Children.Add($band)
            $divider = New-Object System.Windows.Controls.Border
            $divider.BorderBrush = Get-HTBrush '#232A36'
            $divider.BorderThickness = '0,0,1,0'
            [System.Windows.Controls.Grid]::SetRow($divider, $r)
            [void]$grid.Children.Add($divider)
            $label = & $newValueBox $f.Name 13 '#8F99AD'
            $label.Margin = '12,7,14,7'
            [System.Windows.Controls.Grid]::SetRow($label, $r)
            [void]$grid.Children.Add($label)
            $value = & $newValueBox $f.Text 13 '#E4E8EF'
            $value.Margin = '14,7,12,7'
            [System.Windows.Controls.Grid]::SetRow($value, $r)
            [System.Windows.Controls.Grid]::SetColumn($value, 1)
            [void]$grid.Children.Add($value)
            $r++
        }
        $frame = New-Object System.Windows.Controls.Border
        $frame.BorderBrush = Get-HTBrush '#262D39'
        $frame.BorderThickness = 1
        $frame.CornerRadius = 8
        $frame.Padding = 1
        $frame.Child = $grid
        [void]$hostPanel.Children.Add($frame)
    }
    foreach ($f in $fields.Long) {
        $header = New-HTDialogText -Text $f.Name -Color $(if ($f.Body) { '#8CB0FF' } else { '#C9D0DC' }) -Size $(if ($f.Body) { 15 } else { 13.5 })
        $header.FontWeight = 'SemiBold'
        $header.Margin = '0,18,0,6'
        [void]$hostPanel.Children.Add($header)
        $card = New-Object System.Windows.Controls.Border
        $card.Background = Get-HTBrush $(if ($f.Body) { '#161D29' } else { '#161B22' })
        $card.BorderBrush = Get-HTBrush $(if ($f.Body) { '#4C7DF0' } else { '#262D39' })
        $card.BorderThickness = $(if ($f.Body) { '3,1,1,1' } else { '1' })
        $card.CornerRadius = 8
        $card.Padding = '14,12'
        $card.Child = & $newValueBox $f.Text $(if ($f.Body) { 14 } else { 13 }) '#E4E8EF'
        [void]$hostPanel.Children.Add($card)
    }
    $w.Tag.CopyText = Format-HTRowDetails -Module $Module -Row $Row
    $copy = New-HTButton -Text 'Kopiuj' -Icon 'E8C8'
    $copy.add_Click({
            param($s, $e)
            $t = [System.Windows.Window]::GetWindow($s).Tag.CopyText
            if ($t) { Set-HTClipboard $t; Show-HTToast 'Skopiowano do schowka.' 'ok' }
        })
    [void]$w.FindName('dlgExtra').Children.Add($copy)
    [void](Invoke-HTDialog $w)
}

function Copy-HTResultView {
    param([hashtable]$Module, [switch]$SelectedOnly)
    $columns = Get-HTVisibleColumnNames -Module $Module
    if ($columns.Count -eq 0) { return }
    $rows = if ($Module.Grid.SelectedItems.Count -gt 0) { @($Module.Grid.SelectedItems) } elseif ($SelectedOnly) { @() } else { @($Module.View | ForEach-Object { $_ }) }
    if ($rows.Count -eq 0) { return }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($columns -join "`t")
    foreach ($r in $rows) { $lines.Add((($columns | ForEach-Object { ([string](Get-HTExportValue -Module $Module -Row $r -Column $_)) -replace "[`t`r`n]+", ' ' }) -join "`t")) }
    Set-HTClipboard -Text ($lines -join "`r`n") -Secret:($Module.RevealSecrets -and $Module.SecretColumns.Count -gt 0)
    Show-HTToast "Skopiowano wierszy: $($rows.Count)." 'ok'
}

function Invoke-HTTargetAction {
    <#
        Wykonuje operację dla każdego obiektu docelowego i dopisuje wiersze wyników (Obiekt, Status, Szczegóły).
        -Action { param($t) } zwraca tekst szczegółów, hashtablę z dodatkowymi kolumnami albo obiekt.
        Przed zmianą zawsze potwierdzenie: co zostanie zrobione i na których obiektach (Confirm-HTChange).
        -Confirm: tekst pytania; -Summary: opis zmian (domyślnie wartości formularza zatwierdzonego w tej akcji);
        -NoConfirm: tylko dla operacji bez zmian (odczyt, pobieranie) albo gdy potwierdzenie z listą obiektów już było.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action,
        [object[]]$Targets,
        [scriptblock]$Label,
        [string]$Confirm = '',
        [string[]]$Summary = @(),
        [switch]$NoConfirm,
        [switch]$Danger,
        [string]$TypeToConfirm = '',
        [switch]$KeepResults,
        [string]$Service = ''
    )
    $service = if ($PSBoundParameters.ContainsKey('Service')) { $Service } else { $Module.Service }
    if (-not (Assert-HTWriteAllowed -Operation $Name)) { return }
    if ($service -and -not (Assert-HTConnection -Service $service)) { return }
    # Zasada trzech etapów: zakres (lista po lewej) -> sprawdzenie stanu (wyniki) -> zmiana. Zaznaczone wiersze wyników
    # wskazują obiekty do zmiany; bez zaznaczenia - obiekty wybrane na liście po lewej.
    $source = ''
    if (-not $Targets) {
        $fromSelection = @(Get-HTSelectedResultTargets -Module $Module)
        if ($fromSelection.Count) { $Targets = $fromSelection; $source = 'wiersze zaznaczone w wynikach' }
        else { $Targets = @(Get-HTTargets -Module $Module); $source = 'zaznaczone na liście' }
    }
    elseif ($script:UI.TargetSource) { $source = [string]$script:UI.TargetSource }
    $Targets = @($Targets | Where-Object { $null -ne $_ })
    if ($Targets.Count -eq 0) { return }
    if (-not $Label) { $Label = { param($t) Get-HTTargetLabel $t } }
    $labels = @($Targets | ForEach-Object { [string](& $Label $_) })
    if (-not $NoConfirm -and -not (Confirm-HTChange -Name $Name -Labels $labels -Confirm $Confirm -Summary $Summary -Source $source -Danger:$Danger -TypeToConfirm $TypeToConfirm)) { return }
    if (-not $KeepResults) { Reset-HTResults -Module $Module }
    Set-HTBusy -Busy $true -Text "$Name…"
    Start-HTStoppable
    $ok = 0
    $failed = 0
    $stoppedAt = -1
    try {
        for ($i = 0; $i -lt $Targets.Count; $i++) {
            if (Test-HTStopRequested) { $stoppedAt = $i; break }
            $t = $Targets[$i]
            Set-HTProgress -Value ($i + 1) -Maximum $Targets.Count -Text "$Name [$($i + 1)/$($Targets.Count)] $($labels[$i])"
            $row = [ordered]@{ Obiekt = $labels[$i]; Status = 'OK' }
            try {
                $result = & $Action $t
                if ($result -is [System.Collections.IDictionary]) { foreach ($k in $result.Keys) { $row[$k] = $result[$k] } }
                elseif ($result -is [string] -or $result -is [System.ValueType]) { $row['Szczegóły'] = [string]$result }
                elseif ($null -ne $result) { foreach ($p in $result.PSObject.Properties) { $row[$p.Name] = $p.Value } }
                if ($row.Status -eq 'OK') { $ok++ } elseif ([string]$row.Status -like 'Błąd*') { $failed++ }
            }
            catch {
                $row.Status = 'Błąd'
                $row['Szczegóły'] = $_.Exception.Message
                $failed++
            }
            $level = if ($row.Status -eq 'Błąd') { 'Warn' } else { 'Info' }
            $detailText = if ($row.Contains('Szczegóły') -and $Module.SecretColumns -notcontains 'Szczegóły') { [string]$row['Szczegóły'] } else { '' }
            Write-Log -Message "$Name - $($labels[$i]): $($row.Status) $detailText" -Type $level
            Add-HTOperationRecord -Operation $Name -Object $labels[$i] -Status ([string]$row.Status) -Details $detailText -Module $Module.Title
            $row['__target'] = $t
            Add-HTResultRows -Module $Module -Objects @([PSCustomObject]$row)
        }
        # Przerwano: pozostałe obiekty w wynikach jako «Pominięto» - widać, czego nie zmieniono
        if ($stoppedAt -ge 0) {
            $skipped = @(for ($j = $stoppedAt; $j -lt $Targets.Count; $j++) { [PSCustomObject][ordered]@{ Obiekt = $labels[$j]; Status = 'Pominięto'; Szczegóły = 'Przerwano przez użytkownika'; __target = $Targets[$j]; __flag = 'muted' } })
            Add-HTResultRows -Module $Module -Objects $skipped
            Write-Log -Message "Przerwano: $Name - wykonano dla $stoppedAt z $($Targets.Count) obiekt., pominięto: $($skipped.Count) ($(@($labels | Select-Object -Skip $stoppedAt -First 10) -join ', ')$(if ($skipped.Count -gt 10) { ' …' }))" -Type 'Warn'
        }
    }
    finally {
        Stop-HTStoppable
        Set-HTBusy -Busy $false -Text $(if ($stoppedAt -ge 0) { "$Name - przerwano: $ok OK, błędy: $failed, pominięto: $($Targets.Count - $stoppedAt)" } else { "$Name - zakończono: $ok OK, błędy: $failed" })
    }
    if ($stoppedAt -ge 0) { Show-HTToast "$Name - przerwano. Wykonano: $ok, błędy: $failed, pominięto: $($Targets.Count - $stoppedAt)." 'warn'; return }
    $tone = if ($failed -gt 0) { 'warn' } else { 'ok' }
    Show-HTToast "$Name - wykonano: $ok, błędy: $failed." $tone
}

function Confirm-HTChange {
    <#
        Potwierdzenie przed każdą zmianą: co zostanie zrobione i na których obiektach. Zwraca $true/$false;
        decyzja trafia do dziennika (wraz z ustawieniami, bez haseł).
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Labels,
        [string]$Confirm = '',
        [string[]]$Summary = @(),
        [string]$Source = '',
        [switch]$Danger,
        [string]$TypeToConfirm = ''
    )
    if (@($Summary | Where-Object { "$_".Trim() }).Count -eq 0) { $Summary = @(Get-HTPendingFormSummary) }
    $c = Get-HTChangeConfirmation -Name $Name -Labels $Labels -Confirm $Confirm -Summary $Summary -Source $Source
    $answer = Show-HTConfirm -Message $c.Message -Title $Name -Details $c.Details -Items $Labels -ItemsHeader $c.ItemsHeader `
        -Danger:$Danger -Warning:(-not $Danger) -TypeToConfirm $TypeToConfirm -ConfirmText $c.ConfirmText
    if ($answer) { Write-Log -Message "Zatwierdzono: $($c.LogText)" -Type 'Info' }
    else { Write-Log -Message "Anulowano: $($c.LogText)" -Type 'Info' }
    return [bool]$answer
}

function Get-HTTargetLabel {
    # Czytelna nazwa obiektu (do wyników i potwierdzeń)
    param($Target)
    foreach ($p in 'UserPrincipalName', 'PrimarySmtpAddress', 'DeviceName', 'SamAccountName', 'DisplayName', 'Name', 'Title', 'ServerRelativeUrl') {
        $v = Get-HTObjectValue $Target $p
        if ($v) { return [string]$v }
    }
    return [string]$Target
}
#endregion

#region Filtry kolumn tabeli wyników, menu nagłówka i wybór kolumn (jak w Domain Ops)
# Logika filtrów (bez interfejsu) jest w Modules/ColumnFilters.psm1; tutaj lejki w nagłówkach, okienko filtra,
# menu pod prawym przyciskiem (nagłówek: sortowanie, kopiowanie wartości, filtr, ukrywanie kolumn; komórka: szybki filtr).
$script:FilterListLimit = 500

function Find-HTVisualParent {
    param($Element, [type]$Type)
    $e = $Element
    while ($e) {
        if ($e -is $Type) { return $e }
        if ($e -is [System.Windows.Media.Visual] -or $e -is [System.Windows.Media.Media3D.Visual3D]) { $e = [System.Windows.Media.VisualTreeHelper]::GetParent($e) }
        elseif ($e -is [System.Windows.FrameworkContentElement]) { $e = $e.Parent }
        else { $e = $null }
    }
    return $null
}

$script:MenuEvents = @{
    # Pozycja menu: Tag = @{ Module; Action = { param($m, $s) }; Data } - bez rejestru obsługi (menu budowane przy każdym otwarciu)
    Click = {
        param($s, $e)
        $tag = $s.Tag
        if ($tag -is [hashtable] -and $tag.Action) { Invoke-HTUiAction -Module $tag.Module -Action $tag.Action -Source $s }
    }
}

function New-HTMenuItem {
    param([string]$Text, [string]$Icon = '', [hashtable]$Module, [scriptblock]$Action, $Data = $null, [switch]$Danger, [switch]$Create, [bool]$Enabled = $true)
    $mi = New-Object System.Windows.Controls.MenuItem
    $mi.Header = $Text
    if ($Icon) { $mi.Icon = New-HTGlyphBlock -Code $Icon -Size 13 -Color $(if ($Create) { '#5FD39A' } elseif ($Danger) { '#FF7A86' } else { '' }) }
    $mi.IsEnabled = $Enabled
    $mi.Tag = @{ Module = $Module; Action = $Action; Data = $Data }
    if ($Action) { $mi.add_Click($script:MenuEvents.Click) }
    return $mi
}

function New-HTMenuSeparator {
    $sep = New-Object System.Windows.Controls.Separator
    $sep.Style = Get-HTThemeResource 'MenuSeparator'
    return $sep
}

$script:ColumnHeaderEvents = @{
    # Lejek w nagłówku kolumny: moduł z tabeli, w której jest przycisk (bez rejestru obsługi dla każdej kolumny)
    FilterClick = {
        param($s, $e)
        try {
            $grid = Find-HTVisualParent -Element $s -Type ([System.Windows.Controls.DataGrid])
            $m = $null
            if (-not $grid -or -not $script:GridModules.TryGetValue($grid, [ref]$m)) { return }
            Invoke-HTUiAction -Module $m -Action { param($m, $src) Show-HTColumnFilter -Module $m -Column ([string]$src.CommandParameter) -Anchor $src } -Source $s
        }
        catch { Write-Log -Message "Filtr kolumny: $($_.Exception.Message)" -Type 'Error' }
    }
}

$script:GridCopyEvents = @{
    CopyRow = {
        param($s, $e)
        try {
            if (-not $e.IsColumnHeadersRow) { return }
            for ($i = 0; $i -lt $e.ClipboardRowContent.Count; $i++) {
                $c = $e.ClipboardRowContent[$i]
                $text = Get-HTColumnHeaderText -Column $c.Column
                $e.ClipboardRowContent[$i] = New-Object System.Windows.Controls.DataGridClipboardCellContent($c.Item, $c.Column, $text)
            }
        }
        catch { Write-Verbose "Kopiowanie nagłówków: $_" }
    }
}

function Get-HTColumnHeaderText {
    # Tekst nagłówka kolumny tabeli wyników (nagłówek to element: nazwa + lejek filtra)
    param([Parameter(Mandatory)]$Column)
    if ($Column.SortMemberPath) { return [string]$Column.SortMemberPath }
    if ($Column.Header -is [string]) { return $Column.Header }
    $t = @($Column.Header.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] })[0]
    if ($t) { return [string]$t.Text }
    return [string]$Column.Header
}

function New-HTColumnHeader {
    # Nagłówek kolumny: nazwa i lejek filtra
    param([hashtable]$Module, [string]$Name, [switch]$NoFilter)
    $g = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::Auto
    [void]$g.ColumnDefinitions.Add($c1)
    [void]$g.ColumnDefinitions.Add($c2)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Name
    $t.VerticalAlignment = 'Center'
    [void]$g.Children.Add($t)
    if (-not $NoFilter) {
        $b = New-Object System.Windows.Controls.Button
        $b.Style = Get-HTThemeResource 'HeaderFilterButton'
        $b.Margin = '8,0,-6,0'
        $b.CommandParameter = $Name
        [System.Windows.Controls.Grid]::SetColumn($b, 1)
        $b.add_Click($script:ColumnHeaderEvents.FilterClick)
        [void]$g.Children.Add($b)
        if ($Module.FilterButtons) { $Module.FilterButtons[$Name] = $b }
        if ($Module.ColumnFilters -and $Module.ColumnFilters.Contains($Name)) { $b.Tag = 'on' }
    }
    return $g
}

function Set-HTColumnFilter {
    # Ustawia (albo usuwa, gdy brak wartości i warunku) filtr kolumny i odświeża widok
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Column, $Values = $null, [string]$Op = '', [string]$Text = '')
    $set = Set-HTColumnFilterEntry -Module $Module -Column $Column -Values $Values -Op $Op -Text $Text
    Update-HTColumnFilterState -Module $Module
    if ($set) { Write-Log -Message ("Filtr kolumny ({0}) - {1}" -f $Module.Title, (Get-HTColumnFilterText -Module $Module -Column $Column)) -Type 'Info' }
}

function Clear-HTColumnFilters {
    param([Parameter(Mandatory)][hashtable]$Module, [string]$Column = '')
    if ($Column) { [void]$Module.ColumnFilters.Remove($Column) } else { $Module.ColumnFilters.Clear() }
    Update-HTColumnFilterState -Module $Module
}

function Update-HTColumnFilterState {
    # Flagi wierszy, wyróżnienie lejków w nagłówkach, przycisk «Filtry kolumn» i filtr widoku
    param([hashtable]$Module)
    Update-HTColumnFilterFlags -Module $Module
    foreach ($col in @($Module.FilterButtons.Keys)) {
        $Module.FilterButtons[$col].Tag = $(if ($Module.ColumnFilters.Contains($col)) { 'on' } else { $null })
    }
    $chip = $Module.View_['btnFilters']
    if ($chip) {
        $n = $Module.ColumnFilters.Count
        if ($n -gt 0) {
            $chip.Content = New-HTIconContent -Text ("Filtry kolumn: {0}" -f $n) -Icon 'E71C' -IconSize 11
            $chip.ToolTip = (Get-HTColumnFiltersText -Module $Module).Replace(' • ', [Environment]::NewLine) + [Environment]::NewLine + '(kliknij, aby wyczyścić filtry kolumn)'
            $chip.Visibility = 'Visible'
        }
        else { $chip.Visibility = 'Collapsed' }
    }
    Update-HTResultFilter -Module $Module
}

function Set-HTResultSort {
    # Sortowanie tabeli po kolumnie (jak kliknięcie nagłówka)
    param([hashtable]$Module, [string]$Column, [switch]$Descending)
    $g = $Module.Grid
    $dir = if ($Descending) { [System.ComponentModel.ListSortDirection]::Descending } else { [System.ComponentModel.ListSortDirection]::Ascending }
    foreach ($c in $g.Columns) { $c.SortDirection = $(if ([string]$c.SortMemberPath -eq $Column) { $dir } else { $null }) }
    $g.Items.SortDescriptions.Clear()
    $g.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($Column, $dir)))
}

$script:ColumnFilterXaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="#1B212A" BorderBrush="#2F3846" BorderThickness="1" CornerRadius="10" Padding="14,12,14,12" Width="330" Margin="0,4,14,14">
  <Border.Effect>
    <DropShadowEffect BlurRadius="18" ShadowDepth="4" Opacity="0.5" Color="#000000"/>
  </Border.Effect>
  <StackPanel>
    <Grid Margin="0,0,0,8">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,76,0">
        <TextBlock Style="{StaticResource Glyph}" Text="&#xE71C;" FontSize="12" Foreground="#8CB0FF" Margin="0,0,8,0"/>
        <TextBlock x:Name="fTitle" FontWeight="SemiBold" Foreground="#E4E8EF" TextTrimming="CharacterEllipsis"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="fSortAsc" Style="{StaticResource GhostButton}" Padding="7,3" MinHeight="26" ToolTip="Sortuj rosnąco (A → Z, 0 → 9)"/>
        <Button x:Name="fSortDesc" Style="{StaticResource GhostButton}" Padding="7,3" MinHeight="26" ToolTip="Sortuj malejąco (Z → A, 9 → 0)"/>
      </StackPanel>
    </Grid>
    <TextBlock Text="WARUNEK" Foreground="#5E6779" FontSize="10.5" FontWeight="SemiBold" Margin="1,2,0,5"/>
    <Grid Margin="0,0,0,12">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="138"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <ComboBox x:Name="fOp" Margin="0,0,6,0"/>
      <TextBox x:Name="fText" Grid.Column="1" Tag="tekst lub liczba…"/>
    </Grid>
    <Grid Margin="1,0,0,5">
      <TextBlock Text="WARTOŚCI" Foreground="#5E6779" FontSize="10.5" FontWeight="SemiBold"/>
      <TextBlock x:Name="fCount" Foreground="#5E6779" FontSize="10.5" HorizontalAlignment="Right"/>
    </Grid>
    <TextBox x:Name="fSearch" Tag="Szukaj wartości…" Margin="0,0,0,6"/>
    <Border BorderBrush="#2A323F" BorderThickness="1" CornerRadius="6" Background="#161B22">
      <StackPanel>
        <CheckBox x:Name="fAll" Content="(Zaznacz wszystkie)" Margin="10,7,8,5" FontWeight="SemiBold"/>
        <Border Height="1" Background="#242B36" Margin="8,0"/>
        <ScrollViewer x:Name="fScroll" Height="200" VerticalScrollBarVisibility="Auto" Padding="10,4,6,6">
          <StackPanel x:Name="fList"/>
        </ScrollViewer>
      </StackPanel>
    </Border>
    <TextBlock x:Name="fNote" Foreground="#7B8496" FontSize="11.5" TextWrapping="Wrap" Margin="1,6,0,0" Visibility="Collapsed"/>
    <Grid Margin="0,12,0,0">
      <Button x:Name="fClear" Style="{StaticResource GhostButton}" HorizontalAlignment="Left" ToolTip="Usuń filtr tej kolumny"/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="fCancel" Style="{StaticResource GhostButton}" Content="Anuluj" Margin="0,0,6,0"/>
        <Button x:Name="fApply" Style="{StaticResource PrimaryButton}" Content="Filtruj"/>
      </StackPanel>
    </Grid>
  </StackPanel>
</Border>
'@

$script:ColumnFilterUi = $null
$script:ColumnFilterEvents = @{
    ItemToggled = {
        param($s, $e)
        try {
            $ui = $script:ColumnFilterUi
            if ($ui.Rendering) { return }
            $cb = $e.OriginalSource
            if (-not ($cb -is [System.Windows.Controls.CheckBox]) -or $null -eq $cb.Tag) { return }
            if ($cb.IsChecked -eq $true) { [void]$ui.Checked.Add([string]$cb.Tag) } else { [void]$ui.Checked.Remove([string]$cb.Tag) }
            Update-HTColumnFilterAllBox
        }
        catch { Write-Verbose $_ }
    }
    KeyDown     = {
        param($s, $e)
        try {
            if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $script:ColumnFilterUi.Popup.IsOpen = $false; $e.Handled = $true }
            elseif ($e.Key -eq [System.Windows.Input.Key]::Enter -and -not ($e.OriginalSource -is [System.Windows.Controls.ComboBox] -or $e.OriginalSource -is [System.Windows.Controls.ComboBoxItem])) {
                $e.Handled = $true
                Invoke-HTUiAction -Module $script:ColumnFilterUi.Module -Action { param($m) Complete-HTColumnFilterUi }
            }
        }
        catch { Write-Verbose $_ }
    }
}

function Initialize-HTColumnFilterUi {
    # Jedno okienko filtra (Popup) używane przez wszystkie tabele
    if ($script:ColumnFilterUi) { return $script:ColumnFilterUi }
    $root = New-HTUiElement $script:ColumnFilterXaml
    $ui = @{ Root = $root; Module = $null; Column = ''; Values = @(); Matches = @(); Rendering = $false; Checked = $null; AllState = $true }
    foreach ($n in 'fTitle', 'fSortAsc', 'fSortDesc', 'fOp', 'fText', 'fCount', 'fSearch', 'fAll', 'fScroll', 'fList', 'fNote', 'fClear', 'fCancel', 'fApply') { $ui[$n] = $root.FindName($n) }
    foreach ($k in (Get-HTFilterOps).Keys) { [void]$ui.fOp.Items.Add($k) }
    $ui.fSortAsc.Content = New-HTIconContent -Text '' -Icon 'E74A' -IconSize 12
    $ui.fSortDesc.Content = New-HTIconContent -Text '' -Icon 'E74B' -IconSize 12
    $ui.fClear.Content = New-HTIconContent -Text 'Wyczyść' -Icon 'E894' -IconSize 11
    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.Child = $root
    $popup.StaysOpen = $false
    $popup.AllowsTransparency = $true
    $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
    $popup.PopupAnimation = [System.Windows.Controls.Primitives.PopupAnimation]::None
    $ui.Popup = $popup
    $script:ColumnFilterUi = $ui
    $ui.fList.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [System.Windows.RoutedEventHandler]$script:ColumnFilterEvents.ItemToggled)
    $ui.fList.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::UncheckedEvent, [System.Windows.RoutedEventHandler]$script:ColumnFilterEvents.ItemToggled)
    $root.add_PreviewKeyDown($script:ColumnFilterEvents.KeyDown)
    Register-HTControlHandler -Control $ui.fSearch -EventName 'TextChanged' -Module $null -Action { param($m) Update-HTColumnFilterList }
    Register-HTControlHandler -Control $ui.fAll -EventName 'Click' -Module $null -Action {
        param($m)
        $ui = $script:ColumnFilterUi
        # Stan sprzed kliknięcia: częściowy albo pusty -> zaznacz wszystkie (jak w Excelu), pełny -> odznacz
        $on = ($ui.AllState -ne $true)
        foreach ($v in $ui.Matches) { if ($on) { [void]$ui.Checked.Add($v) } else { [void]$ui.Checked.Remove($v) } }
        $ui.Rendering = $true
        try { foreach ($cb in $ui.fList.Children) { if ($cb -is [System.Windows.Controls.CheckBox]) { $cb.IsChecked = $on } } }
        finally { $ui.Rendering = $false }
        Update-HTColumnFilterAllBox
    }
    Register-HTControlHandler -Control $ui.fApply -EventName 'Click' -Module $null -Action { param($m) Complete-HTColumnFilterUi }
    Register-HTControlHandler -Control $ui.fCancel -EventName 'Click' -Module $null -Action { param($m) $script:ColumnFilterUi.Popup.IsOpen = $false }
    Register-HTControlHandler -Control $ui.fClear -EventName 'Click' -Module $null -Action {
        param($m)
        $ui = $script:ColumnFilterUi
        $ui.Popup.IsOpen = $false
        Clear-HTColumnFilters -Module $ui.Module -Column $ui.Column
    }
    Register-HTControlHandler -Control $ui.fSortAsc -EventName 'Click' -Module $null -Action { param($m) $ui = $script:ColumnFilterUi; $ui.Popup.IsOpen = $false; Set-HTResultSort -Module $ui.Module -Column $ui.Column }
    Register-HTControlHandler -Control $ui.fSortDesc -EventName 'Click' -Module $null -Action { param($m) $ui = $script:ColumnFilterUi; $ui.Popup.IsOpen = $false; Set-HTResultSort -Module $ui.Module -Column $ui.Column -Descending }
    return $ui
}

function Show-HTColumnFilter {
    # Okienko filtra kolumny pod lejkiem w nagłówku (albo pod tabelą, gdy wywołane z menu)
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Column, $Anchor = $null)
    $ui = Initialize-HTColumnFilterUi
    $ui.Module = $Module
    $ui.Column = $Column
    $ui.Values = @(Get-HTColumnValueCounts -Module $Module -Column $Column)
    $f = $Module.ColumnFilters[$Column]
    $ui.Checked = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($v in $ui.Values) { if ($null -eq $f -or $null -eq $f.Values -or $f.Values.Contains($v.Text)) { [void]$ui.Checked.Add($v.Text) } }
    $ui.fTitle.Text = $Column
    $ui.fOp.SelectedItem = $(if ($f -and $f.Op) { Get-HTFilterOpLabel $f.Op } else { 'zawiera' })
    $ui.fText.Text = $(if ($f -and $f.Op) { [string]$f.Text } else { '' })
    $ui.fClear.IsEnabled = ($null -ne $f)
    $ui.Rendering = $true
    try { $ui.fSearch.Text = '' } finally { $ui.Rendering = $false }
    Update-HTColumnFilterList
    if (-not $Anchor) { $Anchor = $(if ($Module.FilterButtons.ContainsKey($Column)) { $Module.FilterButtons[$Column] } else { $Module.Grid }) }
    if (-not $Anchor.IsVisible) { $Anchor = $Module.Grid }
    $ui.Popup.PlacementTarget = $Anchor
    $ui.Popup.IsOpen = $true
    [void]$ui.fSearch.Focus()
}

function Update-HTColumnFilterList {
    # Lista pól wyboru wartości (z wyszukiwaniem; najwyżej $script:FilterListLimit pozycji naraz)
    $ui = $script:ColumnFilterUi
    if (-not $ui -or $ui.Rendering) { return }
    $q = $ui.fSearch.Text.Trim()
    $hits = @(if ($q) { $ui.Values | Where-Object { $_.Text.IndexOf($q, [StringComparison]::CurrentCultureIgnoreCase) -ge 0 -or ($_.Text -eq '' -and '(puste)'.Contains($q.ToLowerInvariant())) } } else { $ui.Values })
    $ui.Matches = @($hits | ForEach-Object { $_.Text })
    $ui.Rendering = $true
    try {
        $ui.fList.Children.Clear()
        foreach ($v in @($hits | Select-Object -First $script:FilterListLimit)) {
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $v.Text
            $cb.Margin = '0,3,0,3'
            $cb.IsChecked = $ui.Checked.Contains($v.Text)
            $sp = New-Object System.Windows.Controls.StackPanel
            $sp.Orientation = 'Horizontal'
            $label = New-Object System.Windows.Controls.TextBlock
            if ($v.Text -eq '') { $label.Text = '(puste)'; $label.FontStyle = 'Italic'; $label.Foreground = Get-HTBrush '#8791A5' }
            else { $label.Text = $(if ($v.Text.Length -gt 80) { $v.Text.Substring(0, 80) + '…' } else { $v.Text }) -replace '[\r\n]+', ' ' }
            $label.MaxWidth = 230
            $label.TextTrimming = 'CharacterEllipsis'
            [void]$sp.Children.Add($label)
            $count = New-Object System.Windows.Controls.TextBlock
            $count.Text = '  ' + $v.Count
            $count.Foreground = Get-HTBrush '#5E6779'
            $count.FontSize = 11
            $count.VerticalAlignment = 'Center'
            [void]$sp.Children.Add($count)
            $cb.Content = $sp
            if ($v.Text.Length -gt 30) { $cb.ToolTip = $v.Text }
            [void]$ui.fList.Children.Add($cb)
        }
    }
    finally { $ui.Rendering = $false }
    $ui.fScroll.ScrollToTop()
    $ui.fCount.Text = $(if ($q) { "{0} z {1}" -f $hits.Count, $ui.Values.Count } else { [string]$ui.Values.Count })
    if ($hits.Count -gt $script:FilterListLimit) {
        $ui.fNote.Text = "Pokazano $script:FilterListLimit z $($hits.Count) wartości - zawęź listę wyszukiwaniem albo użyj warunku. «Zaznacz wszystkie» obejmuje także niewidoczne."
        $ui.fNote.Visibility = 'Visible'
    }
    elseif ($q) {
        $ui.fNote.Text = 'Filtr obejmie tylko zaznaczone wartości spośród wyszukanych.'
        $ui.fNote.Visibility = 'Visible'
    }
    else { $ui.fNote.Visibility = 'Collapsed' }
    Update-HTColumnFilterAllBox
}

function Update-HTColumnFilterAllBox {
    $ui = $script:ColumnFilterUi
    $on = 0
    foreach ($v in $ui.Matches) { if ($ui.Checked.Contains($v)) { $on++ } }
    $ui.AllState = $(if ($ui.Matches.Count -gt 0 -and $on -eq $ui.Matches.Count) { $true } elseif ($on -eq 0) { $false } else { $null })
    $ui.Rendering = $true
    try {
        $ui.fAll.IsChecked = $ui.AllState
        $ui.fAll.Content = $(if ($ui.fSearch.Text.Trim()) { '(Zaznacz wszystkie wyszukane)' } else { '(Zaznacz wszystkie)' })
    }
    finally { $ui.Rendering = $false }
}

function Complete-HTColumnFilterUi {
    # «Filtruj»: wybrane wartości + warunek -> filtr kolumny
    $ui = $script:ColumnFilterUi
    $all = @($ui.Values | ForEach-Object { $_.Text })
    $source = if ($ui.fSearch.Text.Trim()) { $ui.Matches } else { $all }
    $selected = @($source | Where-Object { $ui.Checked.Contains($_) })
    # Bezpośrednie przypisanie: pusta tablica (nic nie zaznaczono) nie może zamienić się w $null (= brak filtra)
    $values = $null
    if ($selected.Count -ne $all.Count) { $values = $selected }
    $ops = Get-HTFilterOps
    $op = if ($ui.fOp.SelectedItem) { $ops[[string]$ui.fOp.SelectedItem] } else { '' }
    $text = $ui.fText.Text
    if ($op -ne 'empty' -and $op -ne 'notempty' -and $text.Trim() -eq '') { $op = '' }
    $ui.Popup.IsOpen = $false
    Set-HTColumnFilter -Module $ui.Module -Column $ui.Column -Values $values -Op $op -Text $text.Trim()
}

function Add-HTQuickFilterMenu {
    # Pozycje menu kontekstowego: filtr po wartości klikniętej komórki
    param([hashtable]$Module, $Menu)
    $cell = $Module.MenuCell
    if (-not $cell -or -not $cell.Column -or $Module.SecretColumns -contains $cell.Column -or -not $Module.Table.Columns.Contains($cell.Column)) { return }
    $text = Get-HTFilterText (Get-HTObjectValue $cell.Row $cell.Column)
    $shown = if ($text -eq '') { '(puste)' } elseif ($text.Length -gt 40) { $text.Substring(0, 40) + '…' } else { $text }
    $shown = $shown -replace '[\r\n]+', ' '
    [void]$Menu.Items.Add((New-HTMenuItem -Text ("Pokaż tylko «{0}»" -f $shown) -Icon 'E71C' -Module $Module -Action {
                param($m)
                $c = $m.MenuCell
                Set-HTColumnFilter -Module $m -Column $c.Column -Values @(Get-HTFilterText (Get-HTObjectValue $c.Row $c.Column))
            }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text ("Ukryj «{0}»" -f $shown) -Icon 'E8F6' -Module $Module -Action {
                param($m)
                $c = $m.MenuCell
                $hide = Get-HTFilterText (Get-HTObjectValue $c.Row $c.Column)
                $current = $m.ColumnFilters[$c.Column]
                $keep = @(Get-HTColumnValueCounts -Module $m -Column $c.Column | ForEach-Object { $_.Text } | Where-Object { $_ -ne $hide -and ($null -eq $current -or $null -eq $current.Values -or $current.Values.Contains($_)) })
                Set-HTColumnFilter -Module $m -Column $c.Column -Values $keep -Op $(if ($current) { $current.Op } else { '' }) -Text $(if ($current) { $current.Text } else { '' })
            }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text ("Filtruj kolumnę «{0}»…" -f $cell.Column) -Icon 'E71C' -Module $Module -Action { param($m) Show-HTColumnFilter -Module $m -Column $m.MenuCell.Column }))
    if ($Module.ColumnFilters.Count -gt 0) {
        [void]$Menu.Items.Add((New-HTMenuItem -Text 'Wyczyść filtry kolumn' -Icon 'E894' -Module $Module -Action { param($m) Clear-HTColumnFilters -Module $m }))
    }
}

function Update-HTHeaderMenu {
    # Menu pod prawym przyciskiem na nagłówku kolumny
    param([hashtable]$Module, $Menu, [string]$Column)
    $canFilter = $Module.SecretColumns -notcontains $Column
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Sortuj rosnąco' -Icon 'E74A' -Module $Module -Action { param($m) Set-HTResultSort -Module $m -Column $m.MenuCell.Column }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Sortuj malejąco' -Icon 'E74B' -Module $Module -Action { param($m) Set-HTResultSort -Module $m -Column $m.MenuCell.Column -Descending }))
    [void]$Menu.Items.Add((New-HTMenuSeparator))
    # Wartości całej kolumny (wiersze widoczne po filtrach), każda w osobnej linii
    $count = if ($Module.View) { $Module.View.Count } else { 0 }
    [void]$Menu.Items.Add((New-HTMenuItem -Text ("Kopiuj wartości kolumny ({0})" -f $count) -Icon 'E8C8' -Module $Module -Enabled ($count -gt 0) -Action { param($m) Copy-HTColumnValues -Module $m -Column $m.MenuCell.Column }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Kopiuj wartości bez powtórzeń i pustych' -Icon 'E8C8' -Module $Module -Enabled ($count -gt 0) -Action { param($m) Copy-HTColumnValues -Module $m -Column $m.MenuCell.Column -Unique }))
    [void]$Menu.Items.Add((New-HTMenuSeparator))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Filtruj…' -Icon 'E71C' -Module $Module -Enabled $canFilter -Action { param($m) Show-HTColumnFilter -Module $m -Column $m.MenuCell.Column }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Wyczyść filtr kolumny' -Icon 'E894' -Module $Module -Enabled ($Module.ColumnFilters.Contains($Column)) -Action { param($m) Clear-HTColumnFilters -Module $m -Column $m.MenuCell.Column }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Wyczyść wszystkie filtry kolumn' -Icon 'E894' -Module $Module -Enabled ($Module.ColumnFilters.Count -gt 0) -Action { param($m) Clear-HTColumnFilters -Module $m }))
    [void]$Menu.Items.Add((New-HTMenuSeparator))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Ukryj kolumnę' -Icon 'ED1A' -Module $Module -Action {
                param($m)
                foreach ($c in $m.Grid.Columns) { if ([string]$c.SortMemberPath -eq $m.MenuCell.Column) { $c.Visibility = 'Collapsed' } }
                [void]$m.UserHidden.Add([string]$m.MenuCell.Column)
                Update-HTColumnsButton -Module $m
                Show-HTToast "Ukryto kolumnę «$($m.MenuCell.Column)» - nie trafi do kopiowania ani eksportu. «Pokaż wszystkie kolumny» w menu nagłówka ją przywróci." 'info'
            }))
    $hidden = @($Module.Grid.Columns | Where-Object { $_.Visibility -ne 'Visible' }).Count
    [void]$Menu.Items.Add((New-HTMenuItem -Text $(if ($hidden) { "Pokaż wszystkie kolumny (ukryte: $hidden)" } else { 'Pokaż wszystkie kolumny' }) -Icon 'E7B3' -Module $Module -Enabled ($hidden -gt 0) -Action {
                param($m)
                foreach ($c in $m.Grid.Columns) { $c.Visibility = 'Visible' }
                $m.UserHidden.Clear()
                Update-HTColumnsButton -Module $m
            }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Pokaż tylko tę kolumnę' -Icon 'E8FD' -Module $Module -Action { param($m) Set-HTResultColumns -Module $m -Visible @([string]$m.MenuCell.Column) }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Wybierz kolumny…' -Icon 'E8FD' -Module $Module -Action { param($m) Select-HTResultColumns -Module $m }))
    [void]$Menu.Items.Add((New-HTMenuItem -Text 'Ukryj / pokaż kolumny bez wartości' -Icon 'ED1A' -Module $Module -Action { param($m) Switch-HTEmptyColumns -Module $m }))
}

<#
    Szybkie ukrycie kolumn bez wartości w widocznych wierszach (np. 15 atrybutów niestandardowych, z których wypełnione
    są dwa). Ponowne kliknięcie pokazuje je z powrotem. Kolumna «Obiekt» zostaje zawsze.
#>
function Switch-HTEmptyColumns {
    param([Parameter(Mandatory)][hashtable]$Module)
    if (-not $Module.Grid -or $Module.Grid.Columns.Count -eq 0 -or $null -eq $Module.View) { Show-HTToast 'Brak kolumn - najpierw pobierz dane.' 'info' 3; return }
    $hiddenEmpty = @($Module.Grid.Columns | Where-Object { @($Module['EmptyHidden']) -contains [string]$_.SortMemberPath -and $_.Visibility -ne 'Visible' })
    if ($hiddenEmpty.Count) {
        foreach ($c in $hiddenEmpty) { $c.Visibility = 'Visible' }
        $Module['EmptyHidden'] = @()
        Update-HTColumnsButton -Module $Module
        Show-HTToast "Pokazano kolumny bez wartości: $($hiddenEmpty.Count)." 'info' 3
        return
    }
    $empty = @(foreach ($c in $Module.Grid.Columns) {
            $name = [string]$c.SortMemberPath
            if ($c.Visibility -ne 'Visible' -or -not $name -or $name -eq 'Obiekt') { continue }
            $values = @(Get-HTColumnTextValues -Module $Module -Column $name | Where-Object { $_.Trim() -ne '' })
            if ($values.Count -eq 0) { $name }
        })
    if ($empty.Count -eq 0) { Show-HTToast 'Każda widoczna kolumna ma wartości.' 'info' 3; return }
    if ($empty.Count -ge @($Module.Grid.Columns | Where-Object { $_.Visibility -eq 'Visible' }).Count) { Show-HTToast 'Wszystkie kolumny są puste - nic nie ukryto.' 'info' 3; return }
    foreach ($c in $Module.Grid.Columns) { if ($empty -contains [string]$c.SortMemberPath) { $c.Visibility = 'Collapsed' } }
    $Module['EmptyHidden'] = $empty
    Update-HTColumnsButton -Module $Module
    Show-HTToast "Ukryto kolumny bez wartości: $($empty.Count). Kliknij ponownie, aby je pokazać." 'ok' 4
}

function Update-HTColumnsButton {
    # Przycisk «Kolumny» nad tabelą: liczba kolumn ukrytych przez użytkownika
    param([hashtable]$Module)
    $b = $Module.View_['btnColumns']
    if (-not $b -or -not $Module.Grid) { return }
    $n = @($Module.Grid.Columns | Where-Object { $_.Visibility -ne 'Visible' -and $Module.UserHidden.Contains([string]$_.SortMemberPath) }).Count
    $b.Content = New-HTIconContent -Text $(if ($n) { "ukryte: $n" } else { '' }) -Icon 'E8FD'
    Set-HTToggleButtonState -Button $b -Active ($n -gt 0) -ToolTip $(if ($n) { "Ukryte kolumny: $n - nie trafiają do kopiowania ani eksportu. Kliknij, aby wybrać kolumny." } else { 'Wybierz kolumny do pokazania - ukryte nie trafiają do kopiowania ani eksportu' })
    $e = $Module.View_['btnEmptyCols']
    if ($e) {
        $k = @($Module.Grid.Columns | Where-Object { $_.Visibility -ne 'Visible' -and @($Module['EmptyHidden']) -contains [string]$_.SortMemberPath }).Count
        $e.Content = New-HTIconContent -Text $(if ($k) { "puste: $k" } else { '' }) -Icon 'ED1A'
        Set-HTToggleButtonState -Button $e -Active ($k -gt 0) -ToolTip $(if ($k) { "Ukryto kolumny bez wartości: $k (kliknij, aby je pokazać)" } else { 'Ukryj kolumny bez wartości (kliknij ponownie, aby je pokazać)' })
    }
    Update-HTViewsButton -Module $Module
    # Zapamiętanie ukrytych kolumn modułu (przy następnym uruchomieniu też ukryte)
    if ($Module.Workspace -and $Module.Key) {
        $saved = @(Get-HTModuleHiddenColumns $Module.Key)
        $current = @($Module.UserHidden)
        if (@(Compare-Object -ReferenceObject $saved -DifferenceObject $current).Count -gt 0) { Set-HTModuleHiddenColumns -Key $Module.Key -Columns $current }
    }
}

function Set-HTResultColumns {
    # Widoczne tylko podane kolumny, pozostałe ukryte - także w kopiowaniu i eksporcie, a po odświeżeniu wyników dalej ukryte
    param([Parameter(Mandatory)][hashtable]$Module, [string[]]$Visible)
    foreach ($c in @($Module.Grid.Columns)) {
        $n = [string]$c.SortMemberPath
        if ($Visible -contains $n) { $c.Visibility = 'Visible'; [void]$Module.UserHidden.Remove($n) }
        else { $c.Visibility = 'Collapsed'; [void]$Module.UserHidden.Add($n) }
    }
    Update-HTColumnsButton -Module $Module
}

$script:CheckListEvents = @{
    Filter = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        $q = $s.Text.Trim()
        foreach ($cb in $w.FindName('clList').Children) { $cb.Visibility = if (-not $q -or ([string]$cb.Tag).IndexOf($q, [StringComparison]::CurrentCultureIgnoreCase) -ge 0) { 'Visible' } else { 'Collapsed' } }
    }
    Bulk   = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        foreach ($cb in $w.FindName('clList').Children) {
            if ($cb.Visibility -ne 'Visible') { continue }
            $cb.IsChecked = switch ([string]$s.Tag) { 'All' { $true } 'None' { $false } default { $cb.IsChecked -ne $true } }
        }
    }
}

function Show-HTCheckListDialog {
    # Lista pól wyboru (filtr nazw, zaznacz / odznacz / odwróć widoczne). Zwraca zaznaczone pozycje albo $null (anulowano).
    param([Parameter(Mandatory)][string]$Title, [string]$Prompt = '', [Parameter(Mandatory)][string[]]$Items, [string[]]$Checked = @(), [string]$OkText = 'OK', [string]$Icon = 'E8FD')
    $body = @'
<StackPanel>
  <Grid Margin="0,0,0,8">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*" MinWidth="140"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <TextBox x:Name="clSearch" Tag="Szukaj…" MaxWidth="240" HorizontalAlignment="Stretch" Margin="0,0,10,0"/>
    <StackPanel x:Name="clButtons" Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center"/>
  </Grid>
  <Border Style="{StaticResource Card}" Padding="10,6">
    <ScrollViewer Height="320" VerticalScrollBarVisibility="Auto">
      <StackPanel x:Name="clList"/>
    </ScrollViewer>
  </Border>
</StackPanel>
'@
    $w = New-HTDialog -Title $Title -Subtitle $Prompt -Body $body -Icon $Icon -OkText $OkText -Width 520 -Validate {
        param($w)
        if (-not @($w.FindName('clList').Children | Where-Object { $_.IsChecked -eq $true }).Count) { Show-HTWarning 'Zaznacz co najmniej jedną pozycję.'; return $false }
        return $true
    }
    $list = $w.FindName('clList')
    foreach ($i in $Items) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $i
        $cb.Tag = $i
        $cb.Margin = '0,3,0,3'
        $cb.IsChecked = ($Checked -contains $i)
        [void]$list.Children.Add($cb)
    }
    foreach ($def in @(@('All', 'Zaznacz', 'E73A'), @('None', 'Odznacz', 'E739'), @('Invert', 'Odwróć', 'E8AB'))) {
        $b = New-HTButton -Text $def[1] -Icon $def[2] -Ghost
        $b.Tag = $def[0]
        $b.Margin = '4,0,0,0'
        $b.add_Click($script:CheckListEvents.Bulk)
        [void]$w.FindName('clButtons').Children.Add($b)
    }
    $w.FindName('clSearch').add_TextChanged($script:CheckListEvents.Filter)
    if (-not (Invoke-HTDialog $w)) { return $null }
    return @($list.Children | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { [string]$_.Tag })
}

function Select-HTResultColumns {
    # Okno wyboru kolumn (kolejność zmienia się, przeciągając nagłówki tabeli)
    param([Parameter(Mandatory)][hashtable]$Module)
    $cols = @(if ($Module.Grid) { $Module.Grid.Columns | Sort-Object DisplayIndex })
    if ($cols.Count -eq 0) { Show-HTWarning 'Brak kolumn - najpierw pobierz dane.'; return }
    $names = @($cols | ForEach-Object { [string]$_.SortMemberPath })
    $visible = @($cols | Where-Object { $_.Visibility -eq 'Visible' } | ForEach-Object { [string]$_.SortMemberPath })
    $chosen = Show-HTCheckListDialog -Title 'Kolumny widoku' -Prompt 'Pokazane zostaną tylko zaznaczone kolumny - pozostałe nie trafią do kopiowania ani eksportu (np. lista do importu). Kolejność zmienisz, przeciągając nagłówki tabeli.' -Items $names -Checked $visible -OkText 'Pokaż zaznaczone'
    if ($null -eq $chosen) { return }
    Set-HTResultColumns -Module $Module -Visible $chosen
}

function Get-HTColumnTextValues {
    # Wartości jednej kolumny jako tekst (bez tabulatorów i nowych linii): widoczne wiersze albo zaznaczone; -Unique bez pustych i powtórzeń
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Column, [switch]$SelectedOnly, [switch]$Unique)
    $rows = if ($SelectedOnly) { @($Module.Grid.SelectedItems | Where-Object { $_ -is [System.Data.DataRowView] }) } elseif ($null -ne $Module.View) { @($Module.View | ForEach-Object { $_ }) } else { @() }
    $values = @(foreach ($r in $rows) { ([string](Get-HTExportValue -Module $Module -Row $r -Column $Column)) -replace '[\t\r\n]+', ' ' })
    if ($Unique) {
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $values = @($values | Where-Object { $_.Trim() -ne '' -and $seen.Add($_.Trim()) })
    }
    return $values
}

function Copy-HTColumnValues {
    # Wartości kolumny do schowka - każda w osobnej linii (np. lista UPN do «Zaznacz z listy» w innym module)
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Column, [switch]$SelectedOnly, [switch]$Unique)
    $values = @(Get-HTColumnTextValues -Module $Module -Column $Column -SelectedOnly:$SelectedOnly -Unique:$Unique)
    if ($values.Count -eq 0) { Show-HTWarning "Brak wartości w kolumnie «$Column» do skopiowania."; return }
    Set-HTClipboard -Text ($values -join "`r`n") -Secret:($Module.RevealSecrets -and $Module.SecretColumns -contains $Column)
    Show-HTToast ("Skopiowano wartości kolumny «{0}»: {1}{2}" -f $Column, $values.Count, $(if ($Unique) { ' (bez powtórzeń)' } else { '' })) 'ok'
}
#endregion

#region Zapytania: wyniki dla zaznaczonych obiektów i dane ogólne
function Get-HTResultFlagSummary {
    # Wynik sprawdzenia do podsumowania: liczba wierszy, krytyczne (czerwone) i ostrzeżenia (żółte), błędy obiektów
    param([Parameter(Mandatory)][hashtable]$Module, [int]$Errors = 0)
    $t = $Module.Table
    $count = if ($t) { $t.Rows.Count } else { 0 }
    $warn = 0
    $crit = 0
    if ($t -and $t.Columns.Contains('__flag')) { foreach ($r in $t.Rows) { switch ([string]$r['__flag']) { 'warn' { $warn++ } 'crit' { $crit++ } } } }
    $crit = [Math]::Max(0, $crit - $Errors)
    $parts = @("wyników: $count")
    if ($crit) { $parts += "krytyczne: $crit" }
    if ($warn) { $parts += "ostrzeżenia: $warn" }
    if ($Errors) { $parts += "błędy: $Errors" }
    return ($parts -join ', ')
}

function Add-HTCheckRecord {
    # Sprawdzenie do podsumowania «Do zgłoszenia» (co sprawdzono, gdzie i z jakim wynikiem)
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Name, [string]$Object = '', [string]$Status = 'OK', [string]$Details = '')
    if (-not (Get-Command -Name Add-HTOperationRecord -ErrorAction Ignore)) { return }
    try { Add-HTOperationRecord -Kind Check -Operation $Name -Object $Object -Status $Status -Details $Details -Module ([string]$Module.Title) }
    catch { Write-Verbose "Sprawdzenie $($Name): $_" }
}

function Get-HTCheckScope {
    # Zakres sprawdzenia: połączona witryna SharePoint albo tenant usługi (z paska połączeń)
    param([string]$Service = '')
    $names = $script:UI['ConnectionNames']
    if ($Service -and $names -and $names[$Service]) { return [string]$names[$Service] }
    return ''
}

function Invoke-HTQuery {
    <#
        Pobiera dane i wpisuje je do tabeli wyników modułu: -ScriptBlock zwraca obiekty (wiersze)
        albo sam dopisuje je przez Add-HTResultRows (np. z postępem). Zwraca liczbę wierszy.
        -Background: blok wykonuje się w wątku w tle (okno reaguje, «Przerwij» na pasku stanu), dostaje -Arguments
        jako jedyny parametr i może używać tylko funkcji modułów; wiersze pojawiają się na bieżąco.
        -Record: wpis w podsumowaniu «Do zgłoszenia» - Check (domyślnie, zapytanie do usługi: co sprawdzono i wynik),
        Change (zapytanie, które coś tworzy: każdy nowy wiersz jako zmiana) albo None (operacja zapisuje się sama).
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$Service = '',
        [switch]$KeepResults,
        [switch]$Background,
        [hashtable]$Arguments = @{},
        [ValidateSet('Check', 'Change', 'None')][string]$Record = 'Check',
        [string]$Object = ''
    )
    $service = if ($PSBoundParameters.ContainsKey('Service')) { $Service } else { $Module.Service }
    if ($service -and -not (Assert-HTConnection -Service $service)) { return }
    if (-not $KeepResults) { Reset-HTResults -Module $Module }
    $rowsBefore = if ($Module.Table) { $Module.Table.Rows.Count } else { 0 }
    $scope = if ($Object) { $Object } else { Get-HTCheckScope -Service $service }
    $recordKind = if ($Record -eq 'Check' -and -not $service) { 'None' } else { $Record }
    Set-HTBusy -Busy $true -Text "$Name…"
    $count = 0
    try {
        $done = $false
        if ($Background -and (Test-HTBackgroundAvailable -Service $(if ($service -eq 'Graph' -or -not $service) { 'Graph' } else { $service }))) {
            $batch = New-Object System.Collections.Generic.List[object]
            $flush = { if ($batch.Count) { Add-HTResultRows -Module $Module -Objects $batch.ToArray(); $batch.Clear() } }
            try {
                Invoke-HTBackground -ScriptBlock $ScriptBlock -Arguments $Arguments -Name $Name -OnItem {
                    param($item)
                    if ($null -eq $item) { return }
                    $batch.Add($item)
                    if ($batch.Count -ge 100) { . $flush }
                }
                . $flush
                $done = $true
            }
            catch [System.OperationCanceledException] { . $flush; throw }
            catch {
                . $flush
                if (-not (Test-HTBackgroundAuthError $_)) { throw }
                # Połączenie Graph niedostępne w wątku w tle - dalsze zapytania w wątku okna
                $script:Background.Disabled = $true
                Write-Log -Message "Operacje w tle wyłączone (brak połączenia w wątku w tle): $($_.Exception.Message)" -Type 'Warn'
                Reset-HTResults -Module $Module
            }
        }
        if (-not $done) {
            $data = @(& $ScriptBlock $Arguments | Where-Object { $null -ne $_ })
            if ($data.Count -gt 0) { Add-HTResultRows -Module $Module -Objects $data }
        }
        $count = $Module.Table.Rows.Count
        Write-Log -Message "$Name - wyników: $count" -Type 'Info'
        Set-HTBusy -Busy $false -Text "$Name - wyników: $count"
        if ($recordKind -eq 'Check') { Add-HTCheckRecord -Module $Module -Name $Name -Object $scope -Details (Get-HTResultFlagSummary -Module $Module) }
        elseif ($recordKind -eq 'Change') { Add-HTQueryChangeRecords -Module $Module -Name $Name -From $rowsBefore }
    }
    catch [System.OperationCanceledException] {
        $count = $Module.Table.Rows.Count
        Write-Log -Message "$Name - przerwano (wyników: $count)" -Type 'Warn'
        Set-HTBusy -Busy $false -Text "Przerwano: $Name"
        Show-HTToast "Przerwano: $Name (wyników: $count)" 'warn'
        if ($recordKind -eq 'Check') { Add-HTCheckRecord -Module $Module -Name $Name -Object $scope -Status 'Przerwano' -Details (Get-HTResultFlagSummary -Module $Module) }
        elseif ($recordKind -eq 'Change') { Add-HTQueryChangeRecords -Module $Module -Name $Name -From $rowsBefore }
    }
    catch {
        Write-Log -Message "$Name - błąd: $($_.Exception.Message)" -Type 'Error'
        Set-HTBusy -Busy $false -Text "Błąd: $Name"
        if ($recordKind -eq 'Check') { Add-HTCheckRecord -Module $Module -Name $Name -Object $scope -Status 'Błąd' -Details $_.Exception.Message }
        elseif ($recordKind -eq 'Change' -and (Get-Command -Name Add-HTOperationRecord -ErrorAction Ignore)) { Add-HTOperationRecord -Operation $Name -Object $scope -Status 'Błąd' -Details $_.Exception.Message -Module $Module.Title }
        Show-HTError -Text $Name -ErrorObject $_
    }
}

function Add-HTQueryChangeRecords {
    <#
        Zapytanie, które coś tworzy (np. tworzenie konta): każdy nowy wiersz wyników jako zmiana w podsumowaniu - obiekt
        z kolumny Obiekt / Nazwa / UPN, wynik z kolumny Status, szczegóły z kolumn Szczegóły / Opis (bez haseł).
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Name, [int]$From = 0)
    $t = $Module.Table
    if (-not $t -or -not (Get-Command -Name Add-HTOperationRecord -ErrorAction Ignore)) { return }
    $pick = { param($row, [string[]]$Names) foreach ($n in $Names) { if ($t.Columns.Contains($n) -and -not [string]::IsNullOrWhiteSpace([string]$row[$n])) { return [string]$row[$n] } }; return '' }
    for ($i = [Math]::Max(0, $From); $i -lt $t.Rows.Count; $i++) {
        $row = $t.Rows[$i]
        $status = & $pick $row @('Status')
        $object = & $pick $row @('Obiekt', 'Nazwa', 'UPN', 'UserPrincipalName', 'Grupa')
        $details = @((& $pick $row @('Grupa')), (& $pick $row @('Szczegóły', 'Opis')) | Where-Object { $_ -and $_ -ne $object }) -join ' - '
        Add-HTOperationRecord -Operation $Name -Object $object -Status $(if ($status) { $status } else { 'OK' }) -Details $details -Module $Module.Title
    }
}

function Invoke-HTTargetQuery {
    <#
        Dla każdego obiektu docelowego wykonuje -Action { param($t) } zwracające wiersze wyników.
        Przy kilku obiektach wiersze dostają kolumnę «Obiekt»; każdy wiersz zna swój obiekt (__target).
        Błąd dla obiektu daje wiersz ze statusem «Błąd» - pozostałe obiekty są przetwarzane dalej.
        Microsoft 365 (Graph), kilka obiektów: gdy blok używa tylko funkcji modułów (Test-HTBackgroundSafeBlock),
        wykonuje się w wątku w tle - okno reaguje, wiersze pojawiają się na bieżąco, «Przerwij» działa od razu.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action,
        [object[]]$Targets,
        [scriptblock]$Label,
        [string]$Service = '',
        [switch]$Single,
        [switch]$AlwaysShowObject
    )
    $service = if ($PSBoundParameters.ContainsKey('Service')) { $Service } else { $Module.Service }
    if ($service -and -not (Assert-HTConnection -Service $service)) { return }
    if (-not $Targets) { $Targets = @(Get-HTTargets -Module $Module -Single:$Single) }
    if ($Targets.Count -eq 0) { return }
    if (-not $Label) { $Label = { param($t) Get-HTTargetLabel $t } }
    $showObject = $AlwaysShowObject -or $Targets.Count -gt 1
    $captions = @($Targets | ForEach-Object { [string](& $Label $_) })
    Reset-HTResults -Module $Module
    Set-HTBusy -Busy $true -Text "$Name…"
    if ($Targets.Count -gt 1) { Start-HTStoppable }
    $state = @{ Failed = 0; Done = 0; StoppedAt = -1; AuthFailed = $false }
    # Wiersze wyników jednego obiektu (wspólne dla wątku okna i wątku w tle)
    $addRows = {
        param([int]$Index, [object[]]$Items, [string]$ErrorText)
        $t = $Targets[$Index]
        $caption = $captions[$Index]
        $rows = New-Object System.Collections.Generic.List[object]
        if ($ErrorText) {
            $state.Failed++
            Write-Log -Message "$Name - $($caption): $ErrorText" -Type 'Warn'
            $rows.Add([PSCustomObject][ordered]@{ Obiekt = $caption; Status = 'Błąd'; Szczegóły = $ErrorText; __target = $t; __flag = 'crit' })
        }
        else {
            foreach ($r in @($Items)) {
                if ($null -eq $r) { continue }
                $o = [ordered]@{}
                if ($showObject) { $o['Obiekt'] = $caption }
                $base = if ($r -is [System.Management.Automation.PSObject]) { $r.PSObject.BaseObject } else { $r }
                if ($base -is [System.Collections.IDictionary]) { foreach ($k in $base.Keys) { $o[[string]$k] = $base[$k] } }
                elseif ($base -is [string] -or $base -is [System.ValueType]) { $o['Wynik'] = $base }
                else { foreach ($p in $r.PSObject.Properties) { $o[$p.Name] = $p.Value } }
                $o['__target'] = $t
                $rows.Add([PSCustomObject]$o)
            }
        }
        $state.Done = $Index + 1
        if ($rows.Count -gt 0) { Add-HTResultRows -Module $Module -Objects $rows.ToArray() }
    }
    try {
        $background = $Targets.Count -gt 1 -and $service -eq 'Graph' -and (Test-HTBackgroundAvailable -Service 'Graph') -and (Test-HTBackgroundSafeBlock -ScriptBlock $Action -AllowedModules (@($script:BackgroundModuleNames) + 'Microsoft.Graph.Authentication'))
        if ($background) {
            Write-HTDebug { "$($Name): $($Targets.Count) obiekt. w wątku w tle" }
            try {
                Invoke-HTBackground -Name $Name -Arguments @{ Action = $Action.ToString(); Targets = $Targets; Labels = $captions; Name = $Name } -ScriptBlock {
                    param($a)
                    $run = [scriptblock]::Create($a.Action)
                    for ($i = 0; $i -lt $a.Targets.Count; $i++) {
                        Write-Progress -Activity $a.Name -Status "[$($i + 1)/$($a.Targets.Count)] $($a.Labels[$i])" -PercentComplete ([int](100 * $i / $a.Targets.Count))
                        try { [PSCustomObject]@{ Index = $i; Items = @(& $run $a.Targets[$i]); Error = '' } }
                        catch { [PSCustomObject]@{ Index = $i; Items = @(); Error = [string]$_.Exception.Message } }
                    }
                } -OnItem {
                    param($item)
                    if ($null -eq $item) { return }
                    if ($item.Error -and $item.Error -match 'Authentication needed|Connect-MgGraph|not connected|Nie zalogowano') { $state.AuthFailed = $true }
                    & $addRows ([int]$item.Index) @($item.Items) ([string]$item.Error)
                }
            }
            catch [System.OperationCanceledException] { $state.StoppedAt = $state.Done }
            catch {
                if (-not (Test-HTBackgroundAuthError $_)) { throw }
                $state.AuthFailed = $true
            }
            if ($state.AuthFailed) {
                # Połączenie Graph niedostępne w wątku w tle - całość jeszcze raz w wątku okna
                $script:Background.Disabled = $true
                Write-Log -Message "Operacje w tle wyłączone (brak połączenia w wątku w tle) - $Name w wątku okna." -Type 'Warn'
                Reset-HTResults -Module $Module
                $state.Failed = 0
                $background = $false
            }
        }
        if (-not $background) {
            for ($i = 0; $i -lt $Targets.Count; $i++) {
                if ($Targets.Count -gt 1 -and (Test-HTStopRequested)) { $state.StoppedAt = $i; break }
                if ($Targets.Count -gt 1) { Set-HTProgress -Value ($i + 1) -Maximum $Targets.Count -Text "$Name [$($i + 1)/$($Targets.Count)] $($captions[$i])" }
                $items = $null
                $errorText = ''
                try { $items = @(& $Action $Targets[$i]) } catch { $errorText = [string]$_.Exception.Message }
                & $addRows $i $items $errorText
            }
        }
    }
    finally {
        if ($Targets.Count -gt 1) { Stop-HTStoppable }
        $count = $Module.Table.Rows.Count
        $stopText = if ($state.StoppedAt -ge 0) { ", przerwano po $($state.StoppedAt) z $($Targets.Count) obiekt." } else { '' }
        Set-HTBusy -Busy $false -Text "$Name - wyników: $count$(if ($state.Failed) { ", błędy: $($state.Failed)" })$stopText"
    }
    $stopText = if ($state.StoppedAt -ge 0) { " - przerwano po $($state.StoppedAt) z $($Targets.Count) obiekt." } else { '' }
    Write-Log -Message "$Name ($($Targets.Count) obiekt.) - wyników: $($Module.Table.Rows.Count)$(if ($state.Failed) { ", błędy: $($state.Failed)" })$stopText" -Type $(if ($state.Failed -or $state.StoppedAt -ge 0) { 'Warn' } else { 'Info' })
    # Podsumowanie «Do zgłoszenia»: co sprawdzono (obiekty) i z jakim wynikiem
    if ($service) {
        $shown = @($captions | Select-Object -First 5)
        $scope = ($shown -join ', ') + $(if ($captions.Count -gt $shown.Count) { " i $($captions.Count - $shown.Count) innych" } else { '' })
        $status = if ($state.StoppedAt -ge 0) { 'Przerwano' } elseif ($state.Failed -and $state.Failed -ge $Targets.Count) { 'Błąd' } else { 'OK' }
        Add-HTCheckRecord -Module $Module -Name $Name -Object $scope -Status $status -Details ((Get-HTResultFlagSummary -Module $Module -Errors $state.Failed) + $(if ($state.StoppedAt -ge 0) { ", sprawdzono $($state.StoppedAt) z $($Targets.Count)" } else { '' }))
    }
}

function Get-HTSelectedResultTargets {
    # Obiekty docelowe zaznaczonych wierszy wyników (__target), bez powtórzeń - do zmian po sprawdzeniu stanu
    param([Parameter(Mandatory)][hashtable]$Module)
    if (-not $Module.Grid -or $Module.Grid.SelectedItems.Count -eq 0) { return @() }
    $seen = New-Object System.Collections.Generic.List[object]
    foreach ($o in @(Get-HTResultSelection -Module $Module)) {
        if (-not $o -or -not $o.PSObject.Properties['__target']) { continue }
        $t = $o.__target
        if ($null -eq $t) { continue }
        $already = $false
        foreach ($s in $seen) { if ([object]::ReferenceEquals($s, $t)) { $already = $true; break } }
        if (-not $already) { $seen.Add($t) }
    }
    return $seen.ToArray()
}

function Get-HTRowTarget {
    # Obiekt docelowy, z którego pochodzi wiersz wyników (Invoke-HTTargetQuery / Invoke-HTTargetAction)
    param($Row)
    return Get-HTObjectValue $Row '__target'
}

function Invoke-HTRowAction {
    <#
        Operacja dla zaznaczonych wierszy wyników (menu kontekstowe): -Action { param($row) } zwraca opis wyniku.
        Po zakończeniu opcjonalnie odświeża widok (-Refresh { param($m) }). Potwierdzenie jak w Invoke-HTTargetAction.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)][scriptblock]$Action,
        [scriptblock]$Label,
        [string]$Confirm = '',
        [string[]]$Summary = @(),
        [switch]$NoConfirm,
        [switch]$Danger,
        [string]$TypeToConfirm = '',
        [scriptblock]$Refresh,
        [string]$Service = ''
    )
    $service = if ($PSBoundParameters.ContainsKey('Service')) { $Service } else { $Module.Service }
    if (-not (Assert-HTWriteAllowed -Operation $Name)) { return }
    if ($service -and -not (Assert-HTConnection -Service $service)) { return }
    $Rows = @($Rows | Where-Object { $null -ne $_ })
    if ($Rows.Count -eq 0) { return }
    if (-not $Label) { $Label = { param($r) foreach ($n in 'Nazwa', 'Obiekt', 'Adres', 'UPN', 'Użytkownik', 'Temat', 'Grupa', 'Rola', 'Wartość') { $v = Get-HTObjectValue $r $n; if ($v) { return [string]$v } }; return [string]$r } }
    $labels = @($Rows | ForEach-Object { [string](& $Label $_) })
    if (-not $NoConfirm -and -not (Confirm-HTChange -Name $Name -Labels $labels -Confirm $Confirm -Summary $Summary -Danger:$Danger -TypeToConfirm $TypeToConfirm)) { return }
    Set-HTBusy -Busy $true -Text "$Name…"
    if ($Rows.Count -gt 1) { Start-HTStoppable }
    $ok = 0
    $errors = New-Object System.Collections.Generic.List[string]
    $stoppedAt = -1
    try {
        for ($i = 0; $i -lt $Rows.Count; $i++) {
            if ($Rows.Count -gt 1 -and (Test-HTStopRequested)) { $stoppedAt = $i; break }
            if ($Rows.Count -gt 1) { Set-HTProgress -Value ($i + 1) -Maximum $Rows.Count -Text "$Name [$($i + 1)/$($Rows.Count)] $($labels[$i])" }
            try {
                $detail = & $Action $Rows[$i]
                $ok++
                $detailText = if ($detail -is [string]) { $detail } else { '' }
                Write-Log -Message "$Name - $($labels[$i]): OK $detailText" -Type 'Info'
                Add-HTOperationRecord -Operation $Name -Object $labels[$i] -Status 'OK' -Details $detailText -Module $Module.Title
            }
            catch {
                $errors.Add("$($labels[$i]): $($_.Exception.Message)")
                Write-Log -Message "$Name - $($labels[$i]): $($_.Exception.Message)" -Type 'Warn'
                Add-HTOperationRecord -Operation $Name -Object $labels[$i] -Status 'Błąd' -Details $_.Exception.Message -Module $Module.Title
            }
        }
    }
    finally {
        if ($Rows.Count -gt 1) { Stop-HTStoppable }
        Set-HTBusy -Busy $false -Text "$Name - wykonano: $ok, błędy: $($errors.Count)$(if ($stoppedAt -ge 0) { ", przerwano - pominięto: $($Rows.Count - $stoppedAt)" })"
    }
    $stopNote = ''
    if ($stoppedAt -ge 0) {
        $skipped = @($labels | Select-Object -Skip $stoppedAt)
        $stopNote = "`n`nPrzerwano - pominięto ($($skipped.Count)): $(@($skipped | Select-Object -First 15) -join ', ')$(if ($skipped.Count -gt 15) { ' …' })"
        Write-Log -Message "Przerwano: $Name - wykonano: $ok, pominięto: $($skipped.Count) ($(@($skipped | Select-Object -First 10) -join ', ')$(if ($skipped.Count -gt 10) { ' …' }))" -Type 'Warn'
    }
    if ($errors.Count -gt 0) { Show-HTWarning -Title $Name -Text ("Wykonano: $ok, błędy: $($errors.Count)`n`n" + (($errors | Select-Object -First 30) -join "`n") + $stopNote) }
    elseif ($stoppedAt -ge 0) { Show-HTToast "$Name - przerwano. Wykonano: $ok, pominięto: $($Rows.Count - $stoppedAt)." 'warn' }
    else { Show-HTToast "$Name - wykonano: $ok." 'ok' }
    if ($Refresh -and $ok -gt 0) { Invoke-HTUiAction -Module $Module -Action $Refresh }
}

function Add-HTPanelLoader {
    <#
        Przycisk «Wczytaj» listy obiektów: -Loader { param($p) } zwraca obiekty listy.
        Lista z -Service wczytuje się sama po połączeniu z usługą (Invoke-HTPanelAutoLoad), o ile jest pusta.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Panel,
        [Parameter(Mandatory)][scriptblock]$Loader,
        [string]$Service = '',
        [string]$Text = 'Wczytaj',
        [string]$Icon = 'E72C',
        [string]$ToolTip = 'Wczytaj (odśwież) listę obiektów'
    )
    $Panel.Service = $Service
    $Panel.Loader = $Loader
    return (Add-HTPanelButton -Panel $Panel -Text $Text -Icon $Icon -Primary -ToolTip $ToolTip -OnClick { param($p) Invoke-HTPanelLoad -Panel $p })
}

function Invoke-HTPanelLoad {
    param([Parameter(Mandatory)][hashtable]$Panel, [switch]$Quiet)
    if (-not $Panel.Loader) { return }
    if ($Panel.Service -and -not (Test-HTConnection -Service $Panel.Service)) {
        if (-not $Quiet) { [void](Assert-HTConnection -Service $Panel.Service) }
        return
    }
    $title = $Panel.pTitle.Text.ToLowerInvariant()
    Set-HTBusy -Busy $true -Text "Wczytywanie: $title…"
    try {
        if ($Panel.IsTree) { $null = & $Panel.Loader $Panel }
        else {
            $items = @(& $Panel.Loader $Panel)
            Set-HTTargetItems -Panel $Panel -Items $items
        }
        $count = if ($Panel.IsTree) { $Panel.pTree.Items.Count } else { $Panel.Table.Rows.Count }
        Update-HTTargetCount $Panel
        Write-Log -Message "Wczytano listę '$title': $count" -Type 'Info'
        Set-HTBusy -Busy $false -Text "Wczytano: $count"
    }
    catch {
        Write-Log -Message "Wczytywanie '$title' - błąd: $($_.Exception.Message)" -Type 'Error'
        Set-HTBusy -Busy $false -Text 'Błąd wczytywania'
        if (-not $Quiet) { Show-HTError -Text "Nie udało się wczytać listy: $title" -ErrorObject $_ }
    }
}

function Invoke-HTPanelAutoLoad {
    # Po połączeniu z usługą: wczytuje pustą listę aktywnej przestrzeni; pozostałe wczytają się przy pierwszym otwarciu
    param([Parameter(Mandatory)][string]$Service)
    $active = $script:UI.Workspaces[[string]$script:UI.ActiveWorkspace]
    $panels = @($script:UI.Panels.Values | Where-Object { $_.Service -eq $Service -and $_.Loader })
    $panels = @($panels | Sort-Object { if ($active -and $_.Key -eq $active.Panel) { 0 } else { 1 } })
    foreach ($p in $panels) {
        $empty = if ($p.IsTree) { $p.pTree.Items.Count -eq 0 } else { $p.Table.Rows.Count -eq 0 }
        if ($empty -and $active -and $p.Key -eq $active.Panel) { $p.AutoTried = $true; Invoke-HTPanelLoad -Panel $p -Quiet }
        elseif ($empty) { $p.AutoTried = $false }
    }
}

function Clear-HTPanelItems {
    # Czyści listy obiektów zależne od usługi (np. po rozłączeniu lub zmianie tenantu)
    param([Parameter(Mandatory)][string]$Service)
    foreach ($p in @($script:UI.Panels.Values | Where-Object { $_.Service -eq $Service })) {
        if ($p.IsTree) { $p.pTree.Items.Clear() } else { Set-HTTargetItems -Panel $p -Items @() }
        $p.AutoTried = $false
        Update-HTTargetCount $p
    }
}

function Select-HTOne {
    # Wybór jednego obiektu z listy (okno z wyszukiwaniem); zwraca obiekt albo $null
    param([Parameter(Mandatory)][string]$Title, [AllowEmptyCollection()][object[]]$Items, [object[]]$Columns, [string]$Prompt = '')
    $selected = Show-HTSelectionDialog -Title $Title -Items $Items -Columns $Columns -Prompt $Prompt
    if (-not $selected) { return $null }
    return @($selected)[0]
}
#endregion

#region Blokada programu (PIN i MFA) - jak w Domain Ops
<#
    Ekran PIN przed oknem głównym i blokada w trakcie pracy (przycisk z kłódką, Ctrl+Shift+L, automatycznie po
    bezczynności). Blokada ukrywa zawartość okna głównego i otwartych okien, czyści poufne dane ze schowka;
    połączenia z usługami trwają. Skrót PIN-u (PBKDF2) jest w konfiguracji - zob. Modules/Security.psm1.
    Z włączonym MFA (Modules/Mfa.psm1) po PIN-ie wymagany jest kod z aplikacji; konta dodatkowe mają własny PIN,
    klucz i uprawnienia (wybór konta nad klawiaturą). Z ekranu blokady program można zamknąć bez PIN-u
    przyciskiem «Zakończ awaryjnie» (z potwierdzeniem).
#>
$script:UnlockMaxAttempts = 5
$script:UnlockCooldownSec = 30
$script:UnlockExitConfirmSec = 10
# Emergency: zamknięcie programu z ekranu blokady bez PIN-u; Hidden: okna, których zawartość ukryto na czas blokady;
# LastActivity / Pos: ostatnia aktywność w oknach programu i pozycja kursora (blokada po bezczynności)
$script:LockState = @{ Locked = $false; Emergency = $false; Hidden = @(); LastActivity = [datetime]::Now; Timer = $null; Pos = $null }

$script:UnlockXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="340" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
        Background="#12171D" Foreground="#E4E8EF" FontFamily="Segoe UI" FontSize="13"
        UseLayoutRounding="True" SnapsToDevicePixels="True" TextOptions.TextFormattingMode="Display">
  <Grid Background="#12171D">
    <StackPanel Margin="28,26,28,22">
      <Border Width="52" Height="52" CornerRadius="14" HorizontalAlignment="Center">
        <Border.Background>
          <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#4C7DF0" Offset="0"/>
            <GradientStop Color="#8A5CF0" Offset="1"/>
          </LinearGradientBrush>
        </Border.Background>
        <TextBlock x:Name="lockIcon" Style="{StaticResource Glyph}" FontSize="22" Foreground="White" HorizontalAlignment="Center"/>
      </Border>
      <TextBlock Text="Helpdesk Tools" FontSize="18" FontWeight="SemiBold" Foreground="White" HorizontalAlignment="Center" Margin="0,14,0,0"/>
      <TextBlock x:Name="lockHint" Text="Wpisz PIN, aby uruchomić program" Foreground="#8791A5" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" Margin="0,4,0,0"/>
      <ComboBox x:Name="lockUser" Margin="0,14,0,0" Visibility="Collapsed" ToolTip="Konto MFA"/>
      <StackPanel x:Name="lockDots" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,22,0,0"/>
      <TextBlock x:Name="lockMsg" Foreground="#FF7A86" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" MinHeight="18" Margin="0,12,0,0"/>
      <UniformGrid x:Name="lockPad" Columns="3" Margin="0,12,0,0"/>
      <Button x:Name="lockClose" Content="Zamknij" Style="{StaticResource GhostButton}" HorizontalAlignment="Center" MinWidth="110" Margin="0,14,0,0" Focusable="False"/>
      <Button x:Name="lockExit" Style="{StaticResource GhostButton}" HorizontalAlignment="Center" MinWidth="170" Margin="0,14,0,0" Focusable="False" Visibility="Collapsed"
              ToolTip="Zamyka program bez odblokowania - połączenia z usługami zostaną zakończone"/>
      <TextBlock x:Name="lockExitMsg" Foreground="#E5B567" FontSize="12" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" Margin="0,8,0,0" Visibility="Collapsed"/>
    </StackPanel>
  </Grid>
</Window>
'@

$script:UnlockEvents = @{
    Key      = { param($s, $e) Add-HTUnlockKey -Window ([System.Windows.Window]::GetWindow($s)) -Key ([string]$s.Tag) }
    KeyDown  = {
        param($s, $e)
        # Cyfry z górnego rzędu (bez Shift) i z klawiatury numerycznej; Backspace kasuje cyfrę, Esc i Delete wszystkie
        $k = [string]$e.Key
        $key = ''
        if ($k -match '^NumPad(\d)$') { $key = $Matches[1] }
        elseif ($k -match '^D(\d)$' -and -not ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift)) { $key = $Matches[1] }
        elseif ($k -eq 'Back') { $key = 'Back' }
        elseif ($k -eq 'Escape' -or $k -eq 'Delete') { $key = 'Clear' }
        if (-not $key) { return }
        $e.Handled = $true
        Add-HTUnlockKey -Window $s -Key $key
    }
    Close    = { param($s, $e) Close-HTDialog -Window ([System.Windows.Window]::GetWindow($s)) -Ok $false }
    # Inne konto MFA: od nowa od PIN-u
    User     = { param($s, $e) $w = [System.Windows.Window]::GetWindow($s); $w.FindName('lockMsg').Text = ''; Set-HTUnlockPhase -Window $w -Phase 'Pin' }
    Exit     = { param($s, $e) Request-HTUnlockExit -Window ([System.Windows.Window]::GetWindow($s)) }
    # Okno blokady zamyka poprawny PIN albo potwierdzone zamknięcie awaryjne. Krzyżyk i Alt+F4 działają jak przycisk
    # «Zakończ awaryjnie»: pierwsze naciśnięcie tylko ostrzega, drugie w czasie potwierdzenia zamyka program bez PIN-u.
    Closing  = {
        param($s, $e)
        if ($s.Tag.Mode -ne 'Lock' -or $s.Tag.Result -or $script:LockState.Emergency) { return }
        if ([datetime]::UtcNow -lt $s.Tag.ExitArmed) {
            if ($s.Tag.ExitTimer) { $s.Tag.ExitTimer.Stop() }
            $script:LockState.Emergency = $true
            return
        }
        $e.Cancel = $true
        Request-HTUnlockExit -Window $s
    }
    # Aktywność w oknach programu (klawisz, kliknięcie, kółko myszy) odsuwa blokadę po bezczynności
    Activity = { param($s, $e) $script:LockState.LastActivity = [datetime]::Now }
}

function New-HTUnlockWindow {
    # -Lock: blokada w trakcie pracy (bez «Zamknij», z «Zakończ awaryjnie»; po wyczerpaniu prób przerwa zamiast zamknięcia programu)
    param([switch]$Lock)
    $w = New-HTUiElement $script:UnlockXaml
    $w.Title = $(if ($Lock) { 'Helpdesk Tools - zablokowany' } else { 'Helpdesk Tools - odblokowanie' })
    if ($Lock) {
        $w.FindName('lockClose').Visibility = 'Collapsed'
        # Krzyżyk nie zamyka okna blokady, więc bez PIN-u program można zamknąć tylko tym przyciskiem (z potwierdzeniem)
        $exit = $w.FindName('lockExit')
        $exit.Visibility = 'Visible'
        $exit.Content = New-HTIconContent -Text 'Zakończ awaryjnie' -Icon 'E7E8' -IconSize 12
        $exit.add_Click($script:UnlockEvents.Exit)
    }
    $pad = $w.FindName('lockPad')
    foreach ($key in '1', '2', '3', '4', '5', '6', '7', '8', '9', 'Clear', '0', 'Back') {
        $b = New-Object System.Windows.Controls.Button
        $b.Tag = $key
        $b.Height = 46
        $b.Margin = New-Object System.Windows.Thickness(4)
        # Bez fokusu: spacja lub Enter nie «klikają» ponownie ostatnio użytego przycisku
        $b.Focusable = $false
        if ($key -match '^\d$') {
            $b.Content = $key
            $b.FontSize = 18
        }
        else {
            $b.Content = New-HTGlyphBlock -Code $(if ($key -eq 'Back') { 'E750' } else { 'E894' }) -Size 15
            $b.ToolTip = $(if ($key -eq 'Back') { 'Usuń ostatnią cyfrę (Backspace)' } else { 'Wyczyść (Esc)' })
        }
        $b.add_Click($script:UnlockEvents.Key)
        [void]$pad.Children.Add($b)
    }
    $w.FindName('lockClose').add_Click($script:UnlockEvents.Close)
    $w.add_PreviewKeyDown($script:UnlockEvents.KeyDown)
    $w.add_Closing($script:UnlockEvents.Closing)
    $w.Tag = @{ Result = $false; Modal = $false; Pin = ''; Attempts = 0; Failed = 0; Error = $false; Locked = $false
        Mode = $(if ($Lock) { 'Lock' } else { 'Start' }); LockScreen = $true; CooldownEnd = [datetime]::MinValue
        ExitArmed = [datetime]::MinValue; ExitTimer = $null; Phase = 'Pin'; Need = 4; Accounts = @(); Switched = $false }
    # MFA: konta z pliku (pusta lista - sam PIN); przy kilku kontach wybór konta nad klawiaturą
    $w.Tag.Accounts = @(Get-HTMfaUnlockAccounts)
    if ($w.Tag.Accounts.Count -gt 1) {
        $combo = $w.FindName('lockUser')
        foreach ($a in $w.Tag.Accounts) { [void]$combo.Items.Add([string]$a.Name) }
        # Na ekranie blokady wybrane konto, które pracowało przed blokadą
        $current = (Get-HTAccess).AccountId
        $index = 0
        for ($i = 0; $i -lt $w.Tag.Accounts.Count; $i++) {
            $a = $w.Tag.Accounts[$i]
            if (($current -eq '#primary' -and $a.Primary) -or ($a.Id -and $a.Id -eq $current)) { $index = $i; break }
        }
        $combo.SelectedIndex = $(if ($Lock) { $index } else { 0 })
        $combo.Visibility = 'Visible'
        $combo.add_SelectionChanged($script:UnlockEvents.User)
    }
    Set-HTUnlockPhase -Window $w -Phase 'Pin'
    return $w
}

function Get-HTUnlockAccount {
    # Wybrane konto MFA albo $null (MFA wyłączone)
    param([Parameter(Mandatory)]$Window)
    $list = @($Window.Tag.Accounts)
    if (-not $list.Count) { return $null }
    $i = [Math]::Max(0, $Window.FindName('lockUser').SelectedIndex)
    if ($i -ge $list.Count) { $i = 0 }
    return $list[$i]
}

function Set-HTUnlockPhase {
    # Pin: PIN konta; Code: kod z aplikacji (po poprawnym PIN-ie konta z MFA). Kropki według długości wpisu.
    param([Parameter(Mandatory)]$Window, [ValidateSet('Pin', 'Code')][string]$Phase)
    $st = $Window.Tag
    $acc = Get-HTUnlockAccount -Window $Window
    $st.Phase = $Phase
    $st.Need = if ($Phase -eq 'Code') { [int](Get-HTMfaSettings).Digits }
    elseif ($acc -and -not $acc.Primary -and [int]$acc.PinLength -ge 4) { [int]$acc.PinLength }
    else { [Math]::Max(4, [int]$Global:HTConfig.PinLength) }
    $st.Pin = ''
    $st.Error = $false
    $dots = $Window.FindName('lockDots')
    $dots.Children.Clear()
    $gap = if ($st.Need -gt 5) { 5 } else { 7 }
    for ($i = 0; $i -lt $st.Need; $i++) {
        $d = New-Object System.Windows.Shapes.Ellipse
        $d.Width = 14
        $d.Height = 14
        $d.Margin = New-Object System.Windows.Thickness($gap, 0, $gap, 0)
        $d.StrokeThickness = 2
        [void]$dots.Children.Add($d)
    }
    $who = if ($acc -and @($st.Accounts).Count -gt 1) { " (konto: $($acc.Name))" } else { '' }
    $Window.FindName('lockIcon').Text = Get-HTGlyph $(if ($Phase -eq 'Code') { 'E8EA' } else { 'E72E' })
    $Window.FindName('lockHint').Text = if ($Phase -eq 'Code') { "Wpisz kod z aplikacji uwierzytelniającej$who" }
    elseif ($st.Mode -eq 'Lock') { "Program zablokowany - wpisz PIN$who" }
    else { "Wpisz PIN, aby uruchomić program$who" }
    Update-HTUnlockView -Window $Window
}

function Update-HTUnlockView {
    param([Parameter(Mandatory)]$Window)
    $st = $Window.Tag
    $i = 0
    foreach ($d in $Window.FindName('lockDots').Children) {
        $filled = $i -lt $st.Pin.Length
        $color = if ($st.Error) { '#FF7A86' } elseif ($filled) { '#8CB0FF' } else { '#3A4556' }
        $d.Stroke = Get-HTBrush $color
        $d.Fill = $(if ($filled) { Get-HTBrush $color } else { [System.Windows.Media.Brushes]::Transparent })
        $i++
    }
}

function Add-HTUnlockKey {
    # Cyfra, 'Back' albo 'Clear'; po wpisaniu pełnego PIN-u (albo kodu z aplikacji) od razu sprawdzenie
    param([Parameter(Mandatory)]$Window, [Parameter(Mandatory)][string]$Key)
    $st = $Window.Tag
    if ($st.Locked) { return }
    if ($st.Error) { $st.Error = $false }
    switch -Regex ($Key) {
        '^\d$' { if ($st.Pin.Length -lt $st.Need) { $st.Pin += $Key } }
        '^Back$' { if ($st.Pin.Length) { $st.Pin = $st.Pin.Substring(0, $st.Pin.Length - 1) } }
        '^Clear$' { $st.Pin = '' }
    }
    $msg = $Window.FindName('lockMsg')
    if ($st.Pin.Length -lt $st.Need) { Update-HTUnlockView -Window $Window; return }
    $acc = Get-HTUnlockAccount -Window $Window
    $mfa = [bool]($acc -and -not $acc['NoMfa'])
    $ok = $false
    $codeResult = ''
    $unreadable = 'Nie można odczytać danych MFA tego konta na tym komputerze (usuń plik Mfa.json, aby wrócić do samego PIN-u).'
    try {
        if ($st.Phase -eq 'Code') { $codeResult = Test-HTMfaCodeFor -Account $acc -Code $st.Pin; $ok = ($codeResult -eq 'Ok') }
        elseif ($mfa) { $ok = Test-HTMfaAccountPin -Account $acc -Pin $st.Pin }
        else { $ok = Test-HTPin -Pin $st.Pin }
    }
    catch {
        # Klucza nie da się odczytać (DPAPI: inny komputer albo konto Windows) - bez liczenia próby
        $st.Pin = ''
        Update-HTUnlockView -Window $Window
        $msg.Text = $unreadable
        return
    }
    if ($codeResult -eq 'Used') {
        # Kod poprawny, ale z okna 30 s już użytego (np. ponowna blokada zaraz po odblokowaniu) - bez liczenia próby
        $st.Pin = ''
        Update-HTUnlockView -Window $Window
        $msg.Text = 'Ten kod został już użyty - poczekaj, aż aplikacja pokaże następny (do 30 s).'
        return
    }
    if ($ok -and $st.Phase -eq 'Pin' -and $mfa) {
        # PIN poprawny - teraz kod z aplikacji
        $msg.Text = ''
        Set-HTUnlockPhase -Window $Window -Phase 'Code'
        return
    }
    if ($ok) {
        $st.Pin = ''
        $deny = @()
        if ($mfa -and -not $acc.Primary) {
            # Blokady dostępu konta dodatkowego; bez nich nie odblokowujemy (nie pełny dostęp przez błąd odczytu)
            try { $deny = @((Get-HTMfaAccountSecret -Account $acc).Deny) }
            catch {
                Set-HTUnlockPhase -Window $Window -Phase 'Pin'
                $msg.Text = $unreadable
                return
            }
        }
        $user = if ($mfa) { [string]$acc.Name } else { '' }
        $id = if (-not $mfa -or $acc.Primary) { '#primary' } else { [string]$acc.Id }
        # Inne konto niż przed blokadą: okna poprzedniego konta zamyka Lock-HTApplication (nie wracają na ekran)
        $st.Switched = ($st.Mode -eq 'Lock' -and $id -ne [string](Get-HTAccess).AccountId)
        Set-HTAccessAccount -Name $user -Id $id -Deny $deny
        # Odblokowanie od razu (zanim okno się zamknie): wstrzymane okna mogą się pokazać
        if ($st.Mode -eq 'Lock' -and -not $st.Switched) { Restore-HTAfterLock }
        Close-HTDialog -Window $Window -Ok $true
        return
    }
    $st.Attempts++
    $st.Failed++
    $st.Pin = ''
    $st.Error = $true
    $left = $script:UnlockMaxAttempts - $st.Attempts
    Update-HTUnlockView -Window $Window
    $what = if ($st.Phase -eq 'Code') { 'kod z aplikacji' } else { 'PIN' }
    $who = if ($acc -and @($st.Accounts).Count -gt 1) { ", konto: $($acc.Name)" } else { '' }
    Write-Log -Message "Nieprawidłowy $what (próba $($st.Failed)$who)." -Type 'Warn'
    if ($left -le 0 -and $st.Mode -eq 'Lock') {
        # Blokada w trakcie pracy: przerwa zamiast zamknięcia programu (połączenia z usługami trwają)
        $st.Locked = $true
        $st.CooldownEnd = (Get-Date).AddSeconds($script:UnlockCooldownSec)
        $Window.FindName('lockPad').IsEnabled = $false
        Update-HTUnlockCooldown -Window $Window | Out-Null
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromMilliseconds(250)
        $t.Tag = $Window
        $t.add_Tick({ param($s, $e) if (-not (Update-HTUnlockCooldown -Window $s.Tag)) { $s.Stop() } })
        $t.Start()
        return
    }
    if ($left -le 0) {
        # Komunikat widoczny przez chwilę, potem zamknięcie (bez odblokowania)
        $msg.Text = 'Zbyt wiele błędnych prób - program zostanie zamknięty.'
        $st.Locked = $true
        $Window.FindName('lockPad').IsEnabled = $false
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromMilliseconds(1500)
        $t.Tag = $Window
        $t.add_Tick({ param($s, $e) $s.Stop(); Close-HTDialog -Window $s.Tag -Ok $false })
        $t.Start()
        return
    }
    $msg.Text = '{0} Pozostało prób: {1}' -f $(if ($st.Phase -eq 'Code') { 'Nieprawidłowy kod z aplikacji.' } else { 'Nieprawidłowy PIN.' }), $left
}

function Update-HTUnlockCooldown {
    # Odliczanie przerwy po wyczerpaniu prób; $false, gdy przerwa minęła (klawiatura znów aktywna, nowe próby od PIN-u)
    param([Parameter(Mandatory)]$Window)
    $st = $Window.Tag
    $left = ($st.CooldownEnd - (Get-Date)).TotalSeconds
    $msg = $Window.FindName('lockMsg')
    if ($left -gt 0) {
        $msg.Text = 'Zbyt wiele błędnych prób. Spróbuj ponownie za {0} s.' -f [int][Math]::Ceiling($left)
        return $true
    }
    $st.Locked = $false
    $st.Attempts = 0
    $msg.Text = ''
    $Window.FindName('lockPad').IsEnabled = $true
    Set-HTUnlockPhase -Window $Window -Phase 'Pin'
    return $false
}

function Request-HTUnlockExit {
    <#
        Zamknięcie awaryjne z ekranu blokady: pierwsze kliknięcie tylko uzbraja przycisk (ostrzeżenie pod nim),
        drugie w ciągu kilku sekund zamyka okno blokady bez PIN-u; Lock-HTApplication zamyka wtedy program.
        Działa też w czasie przerwy po błędnych próbach (klawiatura PIN-u jest wtedy wyłączona).
    #>
    param([Parameter(Mandatory)]$Window)
    $st = $Window.Tag
    $exit = $Window.FindName('lockExit')
    $note = $Window.FindName('lockExitMsg')
    if ([datetime]::UtcNow -lt $st.ExitArmed) {
        if ($st.ExitTimer) { $st.ExitTimer.Stop() }
        $script:LockState.Emergency = $true
        Close-HTDialog -Window $Window -Ok $false
        return
    }
    $st.ExitArmed = [datetime]::UtcNow.AddSeconds($script:UnlockExitConfirmSec)
    $exit.Content = New-HTIconContent -Text 'Potwierdź zamknięcie' -Icon 'E7BA' -IconSize 12
    $note.Text = 'Program zostanie zamknięty bez odblokowania, a połączenia z usługami zakończone. Kliknij ponownie (przycisk albo krzyżyk okna), aby potwierdzić.'
    $note.Visibility = 'Visible'
    if (-not $st.ExitTimer) {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromSeconds($script:UnlockExitConfirmSec)
        $t.Tag = $Window
        $t.add_Tick({ param($s, $e) $s.Stop(); Reset-HTUnlockExit -Window $s.Tag })
        $st.ExitTimer = $t
    }
    $st.ExitTimer.Stop()
    $st.ExitTimer.Start()
}

function Reset-HTUnlockExit {
    # Brak potwierdzenia w wyznaczonym czasie: przycisk wraca do stanu wyjściowego
    param([Parameter(Mandatory)]$Window)
    $Window.Tag.ExitArmed = [datetime]::MinValue
    $Window.FindName('lockExit').Content = New-HTIconContent -Text 'Zakończ awaryjnie' -Icon 'E7E8' -IconSize 12
    $note = $Window.FindName('lockExitMsg')
    $note.Text = ''
    $note.Visibility = 'Collapsed'
}

function Show-HTPinSetupDialog {
    # Ustawienie nowego PIN-u (4-8 cyfr, dwukrotnie); zwraca PIN albo $null
    param([string]$Title = 'Ustaw PIN programu', [string]$Subtitle = 'PIN będzie wymagany przy każdym uruchomieniu programu i do odblokowania po blokadzie (kłódka, Ctrl+Shift+L, bezczynność).')
    $body = @'
<StackPanel>
  <TextBlock Text="Nowy PIN (4-8 cyfr)" Foreground="#8791A5" FontSize="12" Margin="0,0,0,5"/>
  <PasswordBox x:Name="pin1" MaxLength="8"/>
  <TextBlock Text="Powtórz PIN" Foreground="#8791A5" FontSize="12" Margin="0,12,0,5"/>
  <PasswordBox x:Name="pin2" MaxLength="8"/>
</StackPanel>
'@
    $w = New-HTDialog -Title $Title -Subtitle $Subtitle -Body $body -Icon 'E72E' -OkText 'Zapisz PIN' -Width 460 -Validate {
        param($w)
        $p1 = $w.FindName('pin1').Password
        if (-not (Test-HTPinFormat $p1)) { Show-HTWarning 'PIN musi składać się z 4-8 cyfr.'; return $false }
        if ($p1 -ne $w.FindName('pin2').Password) { Show-HTWarning 'Wpisane PIN-y różnią się.'; return $false }
        if (-not (Test-HTPinStrength $p1)) { Show-HTWarning 'PIN jest zbyt prosty (powtórzona lub kolejne cyfry).'; return $false }
        return $true
    }
    $w.add_ContentRendered({ param($s, $e) [void]$s.FindName('pin1').Focus() })
    if (-not (Invoke-HTDialog $w)) { return $null }
    return $w.FindName('pin1').Password
}

function Test-HTPinStrength([string]$Pin) {
    # Odrzuca PIN-y z jednej powtórzonej cyfry i kolejnych cyfr (1234, 98765)
    return -not ($Pin -match '^(\d)\1+$' -or '0123456789876543210'.Contains($Pin))
}

function Unlock-HTApplication {
    # Start programu: PIN (przy pierwszym uruchomieniu - ustawienie PIN-u), z MFA także kod. $true - można uruchomić program.
    if (-not (Test-HTPinConfigured)) {
        $pin = Show-HTPinSetupDialog -Subtitle 'Pierwsze uruchomienie: ustaw PIN. Będzie wymagany przy każdym uruchomieniu programu i do odblokowania po blokadzie.'
        if (-not $pin) { return $false }
        Set-HTPin -Pin $pin
        # Nowy PIN po usunięciu starego z konfiguracji nie omija MFA - dalej wymagany kod z aplikacji
        if (-not (Test-HTMfaEnabled)) { Set-HTAccessAccount; return $true }
    }
    $w = New-HTUnlockWindow
    $ok = Invoke-HTDialog $w
    if (-not $ok -and $w.Tag.Failed -gt 0) { Write-Log -Message "Nie odblokowano programu (błędne próby: $($w.Tag.Failed))." -Type 'Warn' }
    if ($ok) {
        $access = Get-HTAccess
        if ($access.Account) {
            $limits = if ($access.Deny.Count) { '; ' + (Get-HTAccessText -Deny @($access.Deny)) } else { '' }
            Write-Log -Message ("Odblokowano program - konto: {0} (PIN i kod z aplikacji){1}." -f $access.Account, $limits) -Type 'Info'
        }
    }
    return $ok
}

function Restore-HTAfterLock {
    # Koniec blokady: zawartość okna głównego i otwartych okien z powrotem (wywołanie wielokrotne bez skutków)
    $script:LockState.Locked = $false
    $script:LockState.LastActivity = [datetime]::Now
    $main = $script:UI.Window
    if ($main -and $main.Content) { $main.Content.Visibility = 'Visible' }
    foreach ($c in @($script:LockState.Hidden)) { try { $c.Visibility = 'Visible' } catch { Write-Verbose $_ } }
    $script:LockState.Hidden = @()
}

function Test-HTLocked { return [bool]$script:LockState.Locked }

function Test-HTEmergencyExit { return [bool]$script:LockState.Emergency }

function Lock-HTApplication {
    <#
        Blokada w trakcie pracy: zawartość okna głównego (i okien już otwartych, np. formularza) ukryta, nad nimi okno PIN
        (modalne). Okna głównego nie ukrywamy - jest pokazane przez ShowDialog, a ukrycie zakończyłoby program.
        Poufne dane w schowku są czyszczone. -IdleMinutes: blokada po bezczynności (inny wpis dziennika).
    #>
    param([int]$IdleMinutes = 0)
    if ($script:LockState.Locked -or $script:LockState.Emergency -or -not (Test-HTPinConfigured)) { return }
    $main = $script:UI.Window
    if (-not $main) { return }
    $script:LockState.Locked = $true
    Clear-HTClipboardSecret
    Write-Log -Message $(if ($IdleMinutes) { "Program zablokowany po $IdleMinutes min bez aktywności." } else { 'Program zablokowany.' }) -Type 'Info'
    if ($main.Content) { $main.Content.Visibility = 'Hidden' }
    $script:LockState.Hidden = @(foreach ($ow in @($main.OwnedWindows)) {
            $c = $ow.Content
            if ($c -is [System.Windows.UIElement] -and $c.Visibility -eq 'Visible') { $c.Visibility = 'Hidden'; $c }
        })
    $w = New-HTUnlockWindow -Lock
    $closed = 0
    try { [void](Invoke-HTDialog $w) }
    finally {
        if ($w.Tag.ExitTimer) { $w.Tag.ExitTimer.Stop() }
        if (-not $script:LockState.Emergency) {
            if ($w.Tag['Switched']) { $closed = Close-HTLockedWindows }
            # Nawigacja według uprawnień konta, które odblokowało - zanim zawartość okna wróci na ekran
            try { Update-HTAccessView } catch { Write-Log -Message "Błąd uprawnień po odblokowaniu: $($_.Exception.Message)" -Type 'Error' }
            Restore-HTAfterLock
        }
    }
    if ($script:LockState.Emergency) {
        Close-HTApplicationEmergency
        return
    }
    $n = [int]$w.Tag.Failed
    $access = Get-HTAccess
    $who = if ($access.Account) { " - konto: $($access.Account), MFA" } else { '' }
    if ($w.Tag['Switched']) { $who += $(if ($closed) { " (zmiana konta - zamknięte okna poprzedniego konta: $closed)" } else { ' (zmiana konta)' }) }
    if ($access.Deny.Count) { $who += '; ' + (Get-HTAccessText -Deny @($access.Deny)) }
    Write-Log -Message ('Program odblokowany{0}{1}.' -f $who, $(if ($n) { " (nieudane próby: $n)" } else { '' })) -Type $(if ($n) { 'Warn' } else { 'Info' })
}

function Close-HTLockedWindows {
    # Inne konto odblokowało program: okna poprzedniego konta ukryte na czas blokady (formularze, potwierdzenia)
    # są zamykane - jak «Anuluj»; zwraca liczbę zamkniętych okien
    $n = 0
    foreach ($c in @($script:LockState.Hidden)) {
        try {
            $win = [System.Windows.Window]::GetWindow($c)
            if ($win) { $win.Close(); $n++ }
        }
        catch { Write-Verbose $_ }
    }
    $script:LockState.Hidden = @()
    return $n
}

function Close-HTApplicationEmergency {
    # Zamknięcie awaryjne z ekranu blokady: otwarte okna i okno główne zamykane bez pytań (zawartość zostaje ukryta);
    # połączenia z usługami kończy obsługa zamykania okna głównego
    $main = $script:UI.Window
    Write-Log -Message 'Zamknięcie awaryjne z ekranu blokady (bez PIN-u).' -Type 'Warn'
    if (-not $main) { return }
    foreach ($ow in @($main.OwnedWindows)) { try { $ow.Close() } catch { Write-Verbose $_ } }
    try { $main.Close() } catch { Write-Verbose $_ }
}

function Update-HTActivity { $script:LockState.LastActivity = [datetime]::Now }

function Register-HTIdleActivity {
    # Okno programu zgłasza aktywność użytkownika (klawisze i przyciski myszy także obsłużone przez kontrolki)
    param([Parameter(Mandatory)][System.Windows.Window]$Window)
    foreach ($ev in [System.Windows.UIElement]::PreviewKeyDownEvent, [System.Windows.UIElement]::PreviewMouseDownEvent, [System.Windows.UIElement]::PreviewMouseWheelEvent) {
        $Window.AddHandler($ev, ($script:UnlockEvents.Activity -as $ev.HandlerType), $true)
    }
}

function Test-HTProgramActive {
    # Czy któreś okno programu (główne albo otwarte z niego) jest aktywne - ruch myszy w innym programie się nie liczy
    $main = $script:UI.Window
    if (-not $main) { return $false }
    if ($main.IsActive) { return $true }
    foreach ($ow in @($main.OwnedWindows)) { if ($ow.IsActive) { return $true } }
    return $false
}

function Test-HTIdleLock {
    <#
        Takt licznika bezczynności (co kilkanaście sekund): ruch kursora nad aktywnym oknem programu też jest aktywnością
        (sprawdzany tutaj, nie w zdarzeniu każdego ruchu myszy). Po AutoLockMinutes minut bez aktywności - blokada.
        Blokada wyłączona (brak PIN-u, 0 minut), już trwa albo trwa operacja (np. logowanie): licznik od nowa.
    #>
    $st = $script:LockState
    $now = [datetime]::Now
    $limit = [int]$Global:AutoLockMinutes
    $main = $script:UI.Window
    if (-not (Test-HTPinConfigured) -or $limit -le 0 -or $st.Locked -or $script:UI.BusyDepth -gt 0 -or -not $main -or -not $main.IsVisible) { $st.LastActivity = $now; return }
    $pos = $null
    try { $pos = $main.PointToScreen([System.Windows.Input.Mouse]::GetPosition($main)) } catch { Write-Verbose $_ }
    if ($null -ne $pos -and $null -ne $st.Pos -and $pos -ne $st.Pos -and (Test-HTProgramActive)) { $st.LastActivity = $now }
    $st.Pos = $pos
    if (($now - $st.LastActivity).TotalMinutes -ge $limit) { Lock-HTApplication -IdleMinutes $limit }
}

function Start-HTAutoLock {
    # Licznik bezczynności (AutoLockMinutes; 0 = wyłączona) - tylko w uruchomionym programie
    $st = $script:LockState
    $st.LastActivity = [datetime]::Now
    if (-not $st.Timer) {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromSeconds(15)
        $t.add_Tick({ param($s, $e) try { Test-HTIdleLock } catch { Write-Log -Message "Błąd blokady po bezczynności: $($_.Exception.Message)" -Type 'Error' } })
        $st.Timer = $t
    }
    $st.Timer.Start()
}

function Stop-HTAutoLock {
    if ($script:LockState.Timer) { $script:LockState.Timer.Stop() }
}

function Wait-HTUnlocked {
    # Okno otwierane w czasie blokady czeka na odblokowanie (albo zamknięcie awaryjne); okno programu dalej reaguje
    if (-not $script:LockState.Locked) { return }
    $frame = New-Object System.Windows.Threading.DispatcherFrame
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(200)
    $t.Tag = $frame
    $t.add_Tick({ param($s, $e) if (-not $script:LockState.Locked -or $script:LockState.Emergency) { $s.Stop(); $s.Tag.Continue = $false } })
    $t.Start()
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

function Clear-HTClipboardSecret {
    # Usuwa ze schowka skopiowaną wartość poufną (hasło, klucz), jeśli nadal tam jest
    try {
        if ($script:Clipboard.Secret -and [System.Windows.Clipboard]::ContainsText() -and [System.Windows.Clipboard]::GetText() -eq $script:Clipboard.Secret) {
            [System.Windows.Clipboard]::Clear()
        }
    }
    catch { Write-Verbose "Schowek: $_" }
    $script:Clipboard.Secret = $null
}
#endregion

#region Uprawnienia kont MFA (dostęp do przestrzeni roboczych, modułów i Ustawień)
# Konto dodatkowe MFA może mieć zablokowane przestrzenie robocze, pojedyncze moduły i Ustawienia programu
# (stan w Modules/Mfa.psm1: Set-HTAccessAccount / Get-HTAccess). Konto podstawowe i program bez MFA - pełny dostęp.
function Test-HTModuleAllowed([string]$Key) {
    $deny = (Get-HTAccess).Deny
    if ($deny.Count -eq 0) { return $true }
    if ($deny.Contains("mod:$Key")) { return $false }
    $d = Get-HTModuleDefinition $Key
    return -not ($d -and $deny.Contains("ws:$($d.Workspace)"))
}

function Test-HTWorkspaceAllowed([string]$Key) {
    # Przestrzeń niezablokowana i z co najmniej jednym dostępnym modułem
    $deny = (Get-HTAccess).Deny
    if ($deny.Count -eq 0) { return $true }
    if ($deny.Contains("ws:$Key")) { return $false }
    foreach ($d in $script:UI.ModuleDefs) { if ($d.Workspace -eq $Key -and -not $deny.Contains("mod:$($d.Key)")) { return $true } }
    return $false
}

function Show-HTAccessDenied([string]$What) {
    $name = (Get-HTAccess).Account
    Write-Log -Message ('Brak dostępu (konto «{0}»): {1}.' -f $name, $What) -Type 'Warn'
    Show-HTToast ('Konto «{0}» nie ma dostępu: {1}.' -f $name, $What) 'warn' 5
}

function Get-HTAccessText {
    # Opis blokad z nazwami przestrzeni i modułów tego programu
    param([string[]]$Deny = @())
    $titles = [ordered]@{}
    foreach ($ws in $script:UI.Workspaces.Values) { $titles[$ws.Key] = $ws.Title }
    return (Get-HTAccessDenyText -Deny $Deny -Workspaces $titles -Modules @($script:UI.ModuleDefs))
}

function Get-HTAccessSummary {
    param([Parameter(Mandatory)][hashtable]$Account)
    try { return (Get-HTAccessText -Deny (Get-HTMfaAccountSecret -Account $Account).Deny) }
    catch { return 'uprawnienia: nie odczytano' }
}

function Update-HTNavAccess {
    # Nawigacja według uprawnień: ukryte zablokowane przestrzenie, moduły i kategorie bez dostępnych modułów
    foreach ($ws in $script:UI.Workspaces.Values) {
        if ($ws.Tab) { $ws.Tab.Visibility = if (Test-HTWorkspaceAllowed $ws.Key) { 'Visible' } else { 'Collapsed' } }
        if (-not $ws.NavHost) { continue }
        $header = $null
        $any = $false
        foreach ($child in @($ws.NavHost.Children)) {
            if ($child -is [System.Windows.Controls.TextBlock]) {
                if ($header) { $header.Visibility = if ($any) { 'Visible' } else { 'Collapsed' } }
                $header = $child
                $any = $false
                continue
            }
            $ok = Test-HTModuleAllowed ([string]$child.Tag)
            $child.Visibility = if ($ok) { 'Visible' } else { 'Collapsed' }
            if ($ok) { $any = $true }
        }
        if ($header) { $header.Visibility = if ($any) { 'Visible' } else { 'Collapsed' } }
    }
    $c = $script:UI.Controls
    if ($c['btnSettings']) { $c.btnSettings.Visibility = if (Test-HTAppAllowed 'Settings') { 'Visible' } else { 'Collapsed' } }
    if ($c['txtUser']) {
        # Konto Windows i - z MFA - konto, które odblokowało program
        $windows = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { [string]$env:USERNAME }
        $account = (Get-HTAccess).Account
        $c.txtUser.Text = if ($account) { "$windows  •  $account" } else { $windows }
        $c.txtUser.ToolTip = if ($account) { "Konto Windows: $windows`nKonto MFA: $account ($(Get-HTAccessText -Deny @((Get-HTAccess).Deny)))" } else { "Konto Windows: $windows" }
    }
    if ($script:UI.HeaderChanged) { try { & $script:UI.HeaderChanged } catch { Write-Verbose $_ } }
}

function Update-HTAccessView {
    # Po zmianie konta: nawigacja i - gdy otwarty moduł jest teraz niedostępny - pierwszy dostępny
    if (-not $script:UI.Window) { return }
    Update-HTNavAccess
    $active = $script:UI.ActiveModule
    if ($script:UI.ActiveWorkspace -and (-not (Test-HTWorkspaceAllowed $script:UI.ActiveWorkspace) -or ($active -and -not (Test-HTModuleAllowed $active.Key)))) {
        Show-HTWorkspace -Key $script:UI.ActiveWorkspace
    }
}
#endregion

#region Okna MFA: włączenie, konta, uprawnienia (Ustawienia > Bezpieczeństwo > «MFA - konta i klucze»)
function Read-HTMfaConfirmation {
    # Potwierdzenie zmiany kodem z aplikacji danego konta; $true = poprawny
    param([Parameter(Mandatory)][hashtable]$Account, [string]$Action = 'zmianę')
    $digits = [int](Get-HTMfaSettings).Digits
    $code = Show-InputBox -Title 'Potwierdź kodem z aplikacji' -Prompt ("Konto «{0}»: wpisz aktualny kod z aplikacji uwierzytelniającej, aby potwierdzić {1}." -f $Account.Name, $Action) -Icon 'E8D7'
    if ($null -eq $code) { return $false }
    if ($code.Trim() -notmatch "^\d{$digits}$") { Show-HTWarning "Kod ma $digits cyfr."; return $false }
    try {
        $res = Test-HTMfaCodeFor -Account $Account -Code $code.Trim()
        if ($res -eq 'Ok') { return $true }
        if ($res -eq 'Used') { Show-HTWarning 'Ten kod został już użyty - poczekaj, aż aplikacja pokaże następny (do 30 s), i spróbuj ponownie.' }
        else {
            Write-Log -Message "MFA: nieprawidłowy kod potwierdzenia (konto «$($Account.Name)»)." -Type 'Warn'
            Show-HTWarning 'Nieprawidłowy kod. Sprawdź, czy zegar telefonu i komputera wskazuje ten sam czas.'
        }
    }
    catch { Show-HTError 'Nie można odczytać danych MFA tego konta na tym komputerze.' $_ }
    return $false
}

$script:MfaEnrollXaml = @'
<StackPanel>
  <TextBlock Text="Nazwa konta (na ekranie blokady i w aplikacji)" Foreground="#8791A5" FontSize="12" Margin="0,0,0,5"/>
  <TextBox x:Name="enName"/>
  <Grid x:Name="enPinPanel" Margin="0,12,0,0">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="14"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <StackPanel>
      <TextBlock Text="PIN tego konta (4-8 cyfr)" Foreground="#8791A5" FontSize="12" Margin="0,0,0,5"/>
      <PasswordBox x:Name="enPin" MaxLength="8"/>
    </StackPanel>
    <StackPanel Grid.Column="2">
      <TextBlock Text="Powtórz PIN" Foreground="#8791A5" FontSize="12" Margin="0,0,0,5"/>
      <PasswordBox x:Name="enPin2" MaxLength="8"/>
    </StackPanel>
  </Grid>
  <Border Style="{StaticResource Card}" Padding="14,12" Margin="0,14,0,0">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border Background="White" CornerRadius="6" Padding="4" Width="186" Height="186" VerticalAlignment="Top" Margin="0,0,16,0">
        <Grid>
          <Image x:Name="enQr" Stretch="Uniform" RenderOptions.BitmapScalingMode="NearestNeighbor"/>
          <TextBlock x:Name="enQrWait" Text="Tworzenie kodu QR…" Foreground="#5E6779" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center"/>
        </Grid>
      </Border>
      <StackPanel Grid.Column="1">
        <TextBlock TextWrapping="Wrap" Foreground="#C9D0DC"
                   Text="1. W aplikacji uwierzytelniającej (Microsoft Authenticator, Google Authenticator i podobne) dodaj konto i zeskanuj kod QR. Bez aparatu: wpisz klucz ręcznie (konto oparte na czasie):"/>
        <TextBox x:Name="enKey" IsReadOnly="True" FontFamily="Consolas" FontSize="16" Margin="0,10,0,0" HorizontalContentAlignment="Center"/>
        <TextBlock x:Name="enLabel" Foreground="#8791A5" FontSize="12" Margin="0,6,0,0" TextWrapping="Wrap"/>
        <WrapPanel x:Name="enButtons" Margin="0,8,0,0"/>
      </StackPanel>
    </Grid>
  </Border>
  <TextBlock Text="2. Wpisz 6-cyfrowy kod, który pokazuje aplikacja" Foreground="#8791A5" FontSize="12" Margin="0,14,0,5"/>
  <TextBox x:Name="enCode" MaxLength="6" Width="150" HorizontalAlignment="Left" FontSize="16"/>
  <TextBlock Foreground="#7B8496" FontSize="12" TextWrapping="Wrap" Margin="0,12,0,0"
             Text="Klucz jest pokazywany tylko teraz. Program zapisuje go zaszyfrowanego (DPAPI) w pliku Mfa.json na tym komputerze - odczyta go tylko to konto Windows. Utrata telefonu: usunięcie pliku Mfa.json przywraca odblokowanie samym PIN-em."/>
</StackPanel>
'@

$script:MfaEnrollEvents = @{
    # Kod QR z linkiem otpauth:// (nazwa konta jest w linku - odświeżany po zmianie nazwy, z opóźnieniem)
    UpdateQr = {
        param($w)
        $n = $w.FindName('enName').Text.Trim()
        $uri = Get-HTMfaUri -Account $(if ($n) { $n } else { 'konto' }) -Base32 (ConvertTo-HTBase32 $w.Tag.Secret)
        $wait = $w.FindName('enQrWait')
        try {
            $w.FindName('enQr').Source = New-HTQrBitmap -QrCode (New-HTQrCode -Text $uri)
            $wait.Visibility = 'Collapsed'
        }
        catch {
            $w.FindName('enQr').Source = $null
            $wait.Text = 'Nie utworzono kodu QR - wpisz klucz ręcznie.'
            $wait.Visibility = 'Visible'
            Write-Log -Message "MFA: kod QR - $($_.Exception.Message)" -Type 'Warn'
        }
    }
    QrTick = {
        param($s, $e)
        $s.Stop()
        $w = $s.Tag
        if ($w -and $w.IsVisible) { & $script:MfaEnrollEvents.UpdateQr $w }
    }
    NameChanged = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if (-not $w -or -not $w.Tag.QrTimer) { return }
        $w.Tag.QrTimer.Stop()
        $w.Tag.QrTimer.Start()
    }
    CopyKey = {
        param($s, $e)
        $win = [System.Windows.Window]::GetWindow($s)
        Set-HTClipboard -Text (ConvertTo-HTBase32 $win.Tag.Secret) -Secret
        Show-HTToast 'Skopiowano klucz - schowek wyczyści się po minucie.' 'ok'
    }
    CopyUri = {
        param($s, $e)
        $win = [System.Windows.Window]::GetWindow($s)
        $n = $win.FindName('enName').Text.Trim()
        Set-HTClipboard -Text (Get-HTMfaUri -Account $(if ($n) { $n } else { 'konto' }) -Base32 (ConvertTo-HTBase32 $win.Tag.Secret)) -Secret
        Show-HTToast 'Skopiowano link - schowek wyczyści się po minucie.' 'ok'
    }
}

function Show-HTMfaEnroll {
    <#
        Włączenie MFA: -Primary - konto podstawowe (PIN programu), bez parametrów - nowe konto dodatkowe (nazwa i własny
        PIN), -Account - nowy klucz istniejącego konta (PIN bez zmian). Klucz generowany tutaj, zapis dopiero po
        poprawnym kodzie z aplikacji. Zwraca $true po zapisaniu.
    #>
    param([switch]$Primary, [hashtable]$Account = $null)
    $title = if ($Account) { "Nowy klucz MFA - $($Account.Name)" } elseif ($Primary) { 'MFA dla konta podstawowego' } else { 'Nowe konto z MFA' }
    $w = New-HTDialog -Title $title -Subtitle 'Odblokowanie programu będzie wymagać PIN-u i kodu z aplikacji w telefonie.' -Body $script:MfaEnrollXaml -Icon 'E8D7' -OkText 'Zapisz' -Width 680 -Validate {
        param($w)
        $t = $w.Tag
        $name = $w.FindName('enName').Text.Trim()
        if (-not $name) { Show-HTWarning 'Podaj nazwę konta.'; return $false }
        if ($name.Length -gt 40) { Show-HTWarning 'Nazwa konta może mieć najwyżej 40 znaków.'; return $false }
        $pin = ''
        if ($t.NeedPin) {
            $pin = $w.FindName('enPin').Password
            if (-not (Test-HTPinFormat $pin)) { Show-HTWarning 'PIN konta musi składać się z 4-8 cyfr.'; return $false }
            if ($pin -ne $w.FindName('enPin2').Password) { Show-HTWarning 'Wpisane PIN-y się różnią.'; return $false }
            if (-not (Test-HTPinStrength $pin)) { Show-HTWarning 'PIN jest zbyt prosty (powtórzona lub kolejne cyfry).'; return $false }
            if (Test-HTPin -Pin $pin) { Show-HTWarning 'PIN konta dodatkowego musi różnić się od PIN-u programu.'; return $false }
        }
        $step = Test-HTTotpCode -Secret $t.Secret -Code $w.FindName('enCode').Text.Trim()
        if ($step -lt 0) { Show-HTWarning 'Kod się nie zgadza. Sprawdź, czy klucz został wpisany bez błędów i czy zegar telefonu i komputera wskazuje ten sam czas.'; return $false }
        try {
            $b32 = ConvertTo-HTBase32 $t.Secret
            if ($t.EditId) { Set-HTMfaAccountKey -Id $t.EditId -Base32 $b32 -Name $name -LastStep $step }
            else { [void](Add-HTMfaAccount -Name $name -Base32 $b32 -Primary:([bool]$t.Primary) -Pin $pin -LastStep $step) }
        }
        catch { Show-HTError 'Nie zapisano konta MFA.' $_; return $false }
        return $true
    }
    $secret = New-HTMfaSecret
    $b32 = ConvertTo-HTBase32 $secret
    $w.Tag.Secret = $secret
    $w.Tag.Primary = [bool]$Primary
    $w.Tag.EditId = $(if ($Account) { [string]$Account.Id } else { '' })
    $w.Tag.NeedPin = (-not $Primary -and -not $Account)
    $nameBox = $w.FindName('enName')
    $nameBox.Text = $(if ($Account) { [string]$Account.Name } elseif ($Primary) { 'Konto podstawowe' } else { '' })
    if (-not $w.Tag.NeedPin) { $w.FindName('enPinPanel').Visibility = 'Collapsed' }
    $w.FindName('enKey').Text = Format-HTMfaKey $b32
    $mfa = Get-HTMfaSettings
    $w.FindName('enLabel').Text = 'Wystawca: {0} • konto: nazwa powyżej • {1} cyfr co {2} s (SHA1)' -f $mfa.Issuer, $mfa.Digits, $mfa.Period
    $buttons = $w.FindName('enButtons')
    $copyKey = New-HTButton -Text 'Kopiuj klucz' -Icon 'E8C8' -ToolTip 'Schowek wyczyści się sam po minucie'
    $copyKey.Margin = '0,0,8,0'
    $copyKey.add_Click($script:MfaEnrollEvents.CopyKey)
    $copyUri = New-HTButton -Text 'Kopiuj link otpauth://' -Icon 'E71B' -ToolTip 'Link do aplikacji, które przyjmują go wklejony (np. menedżery haseł)'
    $copyUri.add_Click($script:MfaEnrollEvents.CopyUri)
    foreach ($b in $copyKey, $copyUri) { [void]$buttons.Children.Add($b) }
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(700)
    $timer.Tag = $w
    $timer.add_Tick($script:MfaEnrollEvents.QrTick)
    $w.Tag.QrTimer = $timer
    # Pierwszy kod QR tuż po pokazaniu okna (tworzenie trwa ok. sekundy - okno pojawia się od razu)
    $initTimer = New-Object System.Windows.Threading.DispatcherTimer
    $initTimer.Interval = [TimeSpan]::FromMilliseconds(60)
    $initTimer.Tag = $w
    $initTimer.add_Tick($script:MfaEnrollEvents.QrTick)
    $w.Tag.QrInitTimer = $initTimer
    $nameBox.add_TextChanged($script:MfaEnrollEvents.NameChanged)
    $w.add_ContentRendered({
            param($s, $e)
            $b = $s.FindName('enName'); [void]$b.Focus(); $b.SelectAll()
            $s.Tag.QrInitTimer.Start()
        })
    $w.add_Closed({ param($s, $e) foreach ($t in $s.Tag.QrTimer, $s.Tag.QrInitTimer) { if ($t) { $t.Stop() } } })
    $ok = Invoke-HTDialog $w
    if ($ok) { Write-Log -Message ('MFA: {0} konto «{1}».' -f $(if ($Account) { 'nowy klucz dla' } else { 'dodano' }), $nameBox.Text.Trim()) -Type 'Info&Notification' }
    return $ok
}

$script:MfaManagerXaml = @'
<StackPanel>
  <TextBlock x:Name="mfInfo" TextWrapping="Wrap" Foreground="#C9D0DC"/>
  <Border Style="{StaticResource Card}" Padding="4" Margin="0,12,0,0">
    <ListBox x:Name="mfList" Height="170" Background="Transparent" BorderThickness="0"/>
  </Border>
  <WrapPanel x:Name="mfButtons" Margin="0,12,0,0"/>
  <TextBlock x:Name="mfFile" Foreground="#7B8496" FontSize="12" TextWrapping="Wrap" Margin="0,10,0,0"/>
</StackPanel>
'@

$script:MfaManagerEvents = @{
    Selection = { param($s, $e) Update-HTMfaManagerButtons -Window ([System.Windows.Window]::GetWindow($s)) }
    Click     = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        try {
            $accounts = @($w.Tag.Accounts)
            $sel = $w.FindName('mfList').SelectedIndex
            $acc = if ($sel -ge 0 -and $sel -lt $accounts.Count) { $accounts[$sel] } else { $null }
            $op = [string]$s.Tag
            $approver = Get-HTMfaApprover -Accounts $accounts -Account $acc
            if ($op -eq 'Primary') { [void](Show-HTMfaEnroll -Primary) }
            elseif ($op -eq 'Add') { if ($approver -and (Read-HTMfaConfirmation -Account $approver -Action 'dodanie nowego konta')) { [void](Show-HTMfaEnroll) } }
            elseif ($op -eq 'Rekey' -and $acc) {
                $action = if ($acc.Id -eq $approver.Id) { 'wygenerowanie nowego klucza' } else { "wygenerowanie nowego klucza dla konta «$($acc.Name)»" }
                if (Read-HTMfaConfirmation -Account $approver -Action $action) { [void](Show-HTMfaEnroll -Account $acc) }
            }
            elseif ($op -eq 'Access' -and $acc -and -not $acc.Primary) {
                if (Read-HTMfaConfirmation -Account $approver -Action "zmianę uprawnień konta «$($acc.Name)»") { [void](Show-HTMfaAccessEditor -Account $acc) }
            }
            elseif ($op -eq 'Remove' -and $acc) { Remove-HTMfaAccountInteractive -Account $acc -Approver $approver -Count $accounts.Count }
        }
        catch { Show-HTError 'Operacja MFA nie powiodła się.' $_ }
        Update-HTMfaManager -Window $w
    }
}

function Show-HTMfaManager {
    # Konta MFA: włączenie dla konta podstawowego, konta dodatkowe, nowy klucz, uprawnienia, usunięcie
    if (-not (Test-HTAppAllowed 'Settings')) { Show-HTAccessDenied 'Ustawienia programu'; return }
    $w = New-HTDialog -Title 'MFA - kody z aplikacji' -Subtitle 'Drugi składnik odblokowania programu na tym komputerze.' -Body $script:MfaManagerXaml -Icon 'E8D7' -OkText 'Zamknij' -NoCancel -Width 640
    $buttons = $w.FindName('mfButtons')
    foreach ($def in @(
            @{ Key = 'Primary'; Text = 'Włącz MFA dla konta podstawowego'; Icon = 'E8D7' },
            @{ Key = 'Add'; Text = 'Dodaj konto…'; Icon = 'E8FA' },
            @{ Key = 'Rekey'; Text = 'Nowy klucz…'; Icon = 'E72C' },
            @{ Key = 'Access'; Text = 'Uprawnienia…'; Icon = 'E72E' },
            @{ Key = 'Remove'; Text = 'Usuń…'; Icon = 'E74D' })) {
        $b = New-HTButton -Text $def.Text -Icon $def.Icon -Danger:($def.Key -eq 'Remove') -Create:($def.Key -eq 'Add')
        $b.Tag = $def.Key
        $b.Margin = '0,0,8,6'
        $b.Name = 'mf' + $def.Key
        try { $w.RegisterName($b.Name, $b) } catch { Write-Verbose $_ }
        $b.add_Click($script:MfaManagerEvents.Click)
        [void]$buttons.Children.Add($b)
    }
    $w.FindName('mfList').add_SelectionChanged($script:MfaManagerEvents.Selection)
    $w.FindName('mfFile').Text = 'Plik: ' + (Get-HTMfaFile)
    Update-HTMfaManager -Window $w
    [void](Invoke-HTDialog $w)
}

function Update-HTMfaManager {
    param([Parameter(Mandatory)]$Window)
    $list = $Window.FindName('mfList')
    $list.Items.Clear()
    $store = $null
    $readError = ''
    try { $store = Read-HTMfaStore } catch { $store = @{ Accounts = @() }; $readError = 'Nie odczytano pliku MFA: ' + $_.Exception.Message }
    $Window.Tag.Accounts = @($store.Accounts | Sort-Object -Property @{ Expression = { -not $_.Primary } }, @{ Expression = { $_.Name } })
    foreach ($a in $Window.Tag.Accounts) {
        $access = if ($a.Primary) { 'pełny dostęp' } else { Get-HTAccessSummary -Account $a }
        $kind = if ($a.Primary) { 'konto podstawowe (PIN programu)' } else { 'konto dodatkowe (własny PIN)' }
        [void]$list.Items.Add(('{0}  -  {1}  •  {2}  •  dodano {3}{4}' -f $a.Name, $kind, $access, $a.Created, $(if ($a.LastUsed) { "  •  ostatnio $($a.LastUsed)" } else { '' })))
    }
    $hasPrimary = @($Window.Tag.Accounts | Where-Object { $_.Primary }).Count -gt 0
    $Window.FindName('mfInfo').Text = if ($readError) { $readError }
    elseif (-not (Test-HTPinConfigured)) { 'Najpierw ustaw PIN programu - MFA nie działa bez PIN-u.' }
    elseif ($hasPrimary) { 'MFA włączone: odblokowanie wymaga PIN-u konta i kodu z aplikacji. Konta dodatkowe mają własny PIN, własny klucz i uprawnienia - na ekranie blokady wybiera się konto. Dodanie konta, nowy klucz, uprawnienia i usunięcie zatwierdza się kodem z aplikacji konta podstawowego.' }
    else { 'MFA wyłączone - program odblokowuje sam PIN. Najpierw włącz MFA dla konta podstawowego, potem możesz dodać kolejne konta (np. dla innych osób z zespołu, z ograniczonym dostępem).' }
    Update-HTMfaManagerButtons -Window $Window
}

function Update-HTMfaManagerButtons {
    param([Parameter(Mandatory)]$Window)
    $accounts = @($Window.Tag.Accounts)
    $hasPrimary = @($accounts | Where-Object { $_.Primary }).Count -gt 0
    $sel = $Window.FindName('mfList').SelectedIndex
    $Window.FindName('mfPrimary').Visibility = if ($hasPrimary) { 'Collapsed' } else { 'Visible' }
    $Window.FindName('mfPrimary').IsEnabled = [bool](Test-HTPinConfigured)
    $Window.FindName('mfAdd').IsEnabled = $hasPrimary
    $Window.FindName('mfRekey').IsEnabled = ($sel -ge 0)
    $Window.FindName('mfAccess').IsEnabled = ($sel -ge 0 -and $sel -lt $accounts.Count -and -not $accounts[$sel].Primary)
    $Window.FindName('mfRemove').IsEnabled = ($sel -ge 0)
}

function Remove-HTMfaAccountInteractive {
    # Usunięcie konta (podstawowego tylko jako ostatniego) po potwierdzeniu kodem konta podstawowego
    param([Parameter(Mandatory)][hashtable]$Account, [Parameter(Mandatory)][hashtable]$Approver, [int]$Count)
    if ($Account.Primary -and $Count -gt 1) { Show-HTWarning 'Najpierw usuń konta dodatkowe - działają tylko razem z MFA konta podstawowego.'; return }
    $action = if ($Account.Primary) { 'wyłączenie MFA' } else { "usunięcie konta «$($Account.Name)»" }
    if (-not (Read-HTMfaConfirmation -Account $Approver -Action $action)) { return }
    $text = if ($Account.Primary) { 'Wyłączyć MFA? Program będzie odblokowywany samym PIN-em, a klucz zostanie usunięty z tego komputera (wpis w aplikacji możesz usunąć ręcznie).' }
    else { "Usunąć konto «$($Account.Name)»? Nie odblokuje już programu (wpis w aplikacji możesz usunąć ręcznie)." }
    if (-not (Show-HTConfirm -Title 'MFA' -Message $text -ConfirmText 'Usuń' -Danger)) { return }
    Remove-HTMfaAccount -Id $Account.Id
    Write-Log -Message ('MFA: usunięto konto «{0}».' -f $Account.Name) -Type 'Warn'
}

$script:AccessEditorXaml = @'
<StackPanel>
  <TextBlock TextWrapping="Wrap" Foreground="#C9D0DC"
             Text="Odznacz przestrzenie robocze albo pojedyncze moduły, do których to konto nie ma mieć dostępu. Zablokowane pozycje znikają z nawigacji po odblokowaniu programu tym kontem."/>
  <WrapPanel x:Name="acButtons" Margin="0,10,0,0"/>
  <Border Style="{StaticResource Card}" Padding="6" Margin="0,10,0,0">
    <TreeView x:Name="acTree" Height="340" BorderThickness="0" Background="Transparent"/>
  </Border>
  <TextBlock x:Name="acSummary" Foreground="#8791A5" FontSize="12" TextWrapping="Wrap" Margin="0,10,0,0"/>
  <TextBlock Foreground="#7B8496" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"
             Text="To ograniczenie w programie. Uprawnienia w Microsoft 365, Exchange i AD wynikają z kont, którymi program łączy się z usługami, i z konta Windows - do rozdzielenia uprawnień między osoby używaj osobnych kont."/>
</StackPanel>
'@

$script:AccessEditorEvents = @{
    Changed = { param($s, $e) Update-HTAccessEditor -Window ([System.Windows.Window]::GetWindow($s)) }
    All     = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        foreach ($b in $w.Tag.Boxes) { $b.IsChecked = $true }
        $w.Tag.Unknown = @()
        Update-HTAccessEditor -Window $w
    }
}

function Get-HTAccessEditorDeny {
    # Blokady z drzewa edytora (+ blokady pozycji, których teraz nie ma)
    param([Parameter(Mandatory)]$Window)
    $t = $Window.Tag
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($b in $t.Boxes) { if ($b.IsChecked -ne $true) { $out.Add([string]$b.Tag) } }
    foreach ($k in $t.Unknown) { if (-not $out.Contains($k)) { $out.Add($k) } }
    return $out.ToArray()
}

function Update-HTAccessEditor {
    param([Parameter(Mandatory)]$Window)
    foreach ($p in $Window.Tag.Workspaces) {
        foreach ($b in $p.Modules) { $b.IsEnabled = ($p.Box.IsChecked -eq $true) }
    }
    $Window.FindName('acSummary').Text = 'Po zapisaniu: ' + (Get-HTAccessText -Deny @(Get-HTAccessEditorDeny -Window $Window))
}

function New-HTAccessCheckBox {
    param([string]$Key, [string]$Text, [string]$Icon = '', [bool]$Allowed, [switch]$Bold)
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = New-HTIconContent -Text $Text -Icon $Icon
    $cb.Tag = $Key
    $cb.IsChecked = $Allowed
    $cb.Margin = '0,2,0,2'
    if ($Bold) { $cb.FontWeight = 'SemiBold' }
    $cb.add_Click($script:AccessEditorEvents.Changed)
    return $cb
}

function Show-HTMfaAccessEditor {
    # Uprawnienia konta dodatkowego: drzewo przestrzeni i modułów + Ustawienia programu; $true po zapisaniu
    param([Parameter(Mandatory)][hashtable]$Account)
    $deny = @((Get-HTMfaAccountSecret -Account $Account).Deny)
    $w = New-HTDialog -Title "Uprawnienia - $($Account.Name)" -Subtitle 'Do czego to konto ma dostęp po odblokowaniu programu.' -Body $script:AccessEditorXaml -Icon 'E72E' -OkText 'Zapisz' -Width 620 -Validate {
        param($w)
        $newDeny = @(Get-HTAccessEditorDeny -Window $w)
        $any = $false
        foreach ($p in $w.Tag.Workspaces) {
            if ($p.Box.IsChecked -eq $true -and @($p.Modules | Where-Object { $_.IsChecked -eq $true }).Count) { $any = $true; break }
        }
        if (-not $any) { Show-HTWarning 'Konto musi mieć dostęp do co najmniej jednego modułu.'; return $false }
        try { Set-HTMfaAccountDeny -Id $w.Tag.AccountId -Deny $newDeny; $w.Tag.Saved = $newDeny }
        catch { Show-HTError 'Nie zapisano uprawnień.' $_; return $false }
        return $true
    }
    $w.Tag.AccountId = [string]$Account.Id
    $w.Tag.Boxes = New-Object System.Collections.ArrayList
    $w.Tag.Workspaces = New-Object System.Collections.ArrayList
    $known = New-Object 'System.Collections.Generic.HashSet[string]'
    $tree = $w.FindName('acTree')
    foreach ($ws in $script:UI.Workspaces.Values) {
        $wsBox = New-HTAccessCheckBox -Key "ws:$($ws.Key)" -Text $ws.Title -Icon $ws.Icon -Allowed ($deny -notcontains "ws:$($ws.Key)") -Bold
        [void]$known.Add([string]$wsBox.Tag)
        [void]$w.Tag.Boxes.Add($wsBox)
        $node = New-Object System.Windows.Controls.TreeViewItem
        $node.Header = $wsBox
        $mods = New-Object System.Collections.ArrayList
        foreach ($d in @($script:UI.ModuleDefs | Where-Object { $_.Workspace -eq $ws.Key })) {
            $mb = New-HTAccessCheckBox -Key "mod:$($d.Key)" -Text $d.Title -Allowed ($deny -notcontains "mod:$($d.Key)")
            [void]$known.Add([string]$mb.Tag)
            [void]$w.Tag.Boxes.Add($mb)
            [void]$mods.Add($mb)
            $child = New-Object System.Windows.Controls.TreeViewItem
            $child.Header = $mb
            [void]$node.Items.Add($child)
            if ($deny -contains "mod:$($d.Key)") { $node.IsExpanded = $true }
        }
        [void]$w.Tag.Workspaces.Add(@{ Box = $wsBox; Modules = @($mods); Node = $node })
        [void]$tree.Items.Add($node)
    }
    $appNode = New-Object System.Windows.Controls.TreeViewItem
    $appHeader = New-Object System.Windows.Controls.TextBlock
    $appHeader.Text = 'Program'
    $appHeader.FontWeight = 'SemiBold'
    $appHeader.Foreground = Get-HTBrush '#C9D0DC'
    $appNode.Header = $appHeader
    $appNode.IsExpanded = $true
    $setBox = New-HTAccessCheckBox -Key 'app:Settings' -Text 'Ustawienia programu (w tym zarządzanie MFA)' -Icon 'E713' -Allowed ($deny -notcontains 'app:Settings')
    [void]$known.Add('app:Settings')
    [void]$w.Tag.Boxes.Add($setBox)
    $setItem = New-Object System.Windows.Controls.TreeViewItem
    $setItem.Header = $setBox
    [void]$appNode.Items.Add($setItem)
    $writeBox = New-HTAccessCheckBox -Key 'app:Write' -Text 'Wprowadzanie zmian (bez zaznaczenia - tylko podgląd i raporty)' -Icon 'E70F' -Allowed ($deny -notcontains 'app:Write')
    [void]$known.Add('app:Write')
    [void]$w.Tag.Boxes.Add($writeBox)
    $writeItem = New-Object System.Windows.Controls.TreeViewItem
    $writeItem.Header = $writeBox
    [void]$appNode.Items.Add($writeItem)
    [void]$tree.Items.Add($appNode)
    $w.Tag.Unknown = @($deny | Where-Object { -not $known.Contains($_) })
    $all = New-HTButton -Text 'Pełny dostęp' -Icon 'E73E' -ToolTip 'Zaznacza wszystkie przestrzenie, moduły i Ustawienia'
    $all.add_Click($script:AccessEditorEvents.All)
    [void]$w.FindName('acButtons').Children.Add($all)
    Update-HTAccessEditor -Window $w
    if (-not (Invoke-HTDialog $w)) { return $false }
    $saved = @($w.Tag.Saved)
    Write-Log -Message ('MFA: uprawnienia konta «{0}»: {1}.' -f $Account.Name, (Get-HTAccessText -Deny $saved)) -Type 'Info&Notification'
    $access = Get-HTAccess
    if ($access.AccountId -eq [string]$Account.Id) {
        # Zmienione uprawnienia konta, które teraz pracuje - od razu
        Set-HTAccessAccount -Name $access.Account -Id $access.AccountId -Deny $saved
        Update-HTAccessView
    }
    return $true
}

function Get-HTMfaStatusText {
    # Opis stanu MFA do okna Ustawień
    $n = 0
    try { $n = @((Read-HTMfaStore).Accounts).Count } catch { return 'Nie odczytano pliku MFA.' }
    if (-not (Test-HTPinConfigured)) { return 'PIN programu nie jest ustawiony.' }
    if ($n) { return "MFA włączone - kont: $n. Odblokowanie wymaga PIN-u i kodu z aplikacji w telefonie." }
    return 'MFA wyłączone - program odblokowuje sam PIN. Można dodać kod z aplikacji (Microsoft / Google Authenticator).'
}
#endregion

#region Tryb tylko do odczytu (konta MFA)
function Assert-HTWriteAllowed {
    # Konto MFA w trybie tylko do odczytu (Uprawnienia… > «Wprowadzanie zmian») nie wykona operacji zmieniającej
    param([string]$Operation = 'zmiana')
    if (Test-HTWriteAllowed) { return $true }
    Show-HTAccessDenied ("$Operation (tryb tylko do odczytu)")
    return $false
}
#endregion

#region Operacje w tle (zapytania Microsoft Graph w osobnym wątku)
<#
    Zapytania oznaczone -Background (Invoke-HTQuery) wykonują się w puli wątków z modułami programu i modułem
    Microsoft.Graph.Authentication - połączenie Graph jest wspólne dla procesu. Okno w tym czasie reaguje (przełączanie
    modułów, przewijanie), wiersze pojawiają się na bieżąco, a przycisk «Przerwij» na pasku stanu kończy zapytanie.
    Blok zapytania dostaje jeden parametr (-Arguments) i może korzystać tylko z funkcji modułów (nie z plików GUI).
    Gdy połączenie nie jest dostępne w wątku (np. inna wersja modułu Graph), zapytania wracają do wątku okna.
#>
$script:Background = @{ Pool = $null; PoolModules = ''; Disabled = $false; Current = $null; Tasks = (New-Object System.Collections.ArrayList); Timer = $null }
$script:BackgroundModuleNames = @('Utils', 'Security', 'Mfa', 'ModulesConnection', 'GraphAPIM365Users', 'GraphAPIIntune', 'GraphAPISharePoint',
    'GraphAPISecurity', 'GraphAPITeams', 'SharePointAudit', 'Reports', 'Excel', 'Integrations', 'Automation', 'ColumnFilters')

$script:BackgroundWorker = @'
param($Code, $Arguments, $Globals, $LogQueue)
foreach ($k in $Globals.Keys) { Set-Variable -Name $k -Value $Globals[$k] -Scope Global }
# Dziennik w tle bez zapisu do pliku - wpisy przekazuje i zapisuje okno programu
$Global:HTNoLogFile = $true
Clear-HTLogSinks
Clear-HTLogHistory
Register-HTLogSink -ScriptBlock { param($entry) $LogQueue.Enqueue($entry) }.GetNewClosure()
$block = [scriptblock]::Create($Code)
& $block $Arguments
'@

function Get-HTBackgroundGlobals {
    # Ustawienia programu potrzebne funkcjom modułów w wątku w tle
    $g = @{}
    foreach ($n in 'DefaultUsageLocation', 'InactiveDays', 'GraphScopes', 'PasswordDefaultLength', 'PasswordSpecialCharacters', 'PasswordUseWordBased', 'AppVersion', 'HTActiveAccount', 'ExportPath', 'HTConfig', 'ConfigDir', 'LogDir') {
        $g[$n] = Get-Variable -Name $n -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    }
    $g.ConnectedToGraphAPI = [bool]$Global:ConnectedToGraphAPI
    $g.ConnectedToExchange = $false
    $g.ConnectedToSharepointPnP = $false
    $g.ShowNotifications = $false
    return $g
}

function Get-HTBackgroundModulePaths {
    param([string[]]$Names = $script:BackgroundModuleNames, [switch]$NoGraph)
    $paths = New-Object System.Collections.Generic.List[string]
    if (-not $NoGraph) {
        $graph = @(Get-Module -Name Microsoft.Graph.Authentication)[0]
        if ($graph) {
            $manifest = Join-Path $graph.ModuleBase "$($graph.Name).psd1"
            $paths.Add($(if (Test-Path -LiteralPath $manifest) { $manifest } else { $graph.Path }))
        }
    }
    foreach ($name in $Names) {
        $mod = @(Get-Module -Name $name)[0]
        if ($mod -and $mod.Path) { $paths.Add($mod.Path) }
    }
    return $paths.ToArray()
}

function Get-HTBackgroundPool {
    # Pula wątków z modułami programu (tworzona przy pierwszym użyciu, odtwarzana po zmianie załadowanych modułów).
    # -Async: otwieranie bez czekania (przygotowanie zaraz po połączeniu z Microsoft 365).
    param([switch]$Async)
    $bg = $script:Background
    $paths = @(Get-HTBackgroundModulePaths)
    $signature = $paths -join '|'
    if ($bg.Pool -and $bg.PoolModules -eq $signature) {
        $state = "$($bg.Pool.RunspacePoolStateInfo.State)"
        if ($state -eq 'Opened' -or ($Async -and $state -eq 'Opening')) { return $bg.Pool }
        if ($state -eq 'Opening') {
            $limit = [datetime]::Now.AddSeconds(90)
            while ("$($bg.Pool.RunspacePoolStateInfo.State)" -eq 'Opening' -and [datetime]::Now -lt $limit) { Update-HTUi; Start-Sleep -Milliseconds 50 }
            if ("$($bg.Pool.RunspacePoolStateInfo.State)" -eq 'Opened') { return $bg.Pool }
        }
    }
    if ($bg.Pool) { try { $bg.Pool.Dispose() } catch { Write-Verbose $_ } }
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    $iss.ImportPSModule([string[]]$paths)
    # Bez hosta okna: Write-Progress trafia do strumienia postępu (pasek stanu), Write-Host jest pomijany
    $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool($iss)
    [void]$pool.SetMaxRunspaces(2)
    $bg.Pool = $pool
    $bg.PoolModules = $signature
    if ($Async) { [void]$pool.BeginOpen($null, $null); return $pool }
    $opening = $pool.BeginOpen($null, $null)
    while (-not $opening.IsCompleted) { Update-HTUi; Start-Sleep -Milliseconds 50 }
    $pool.EndOpen($opening)
    return $pool
}

function Start-HTBackgroundWarmup {
    # Przygotowanie wątków w tle zaraz po połączeniu z Microsoft 365 (pierwsze zapytanie nie czeka na import modułów)
    if (-not $Global:BackgroundQueries -or $script:Background.Disabled) { return }
    try { [void](Get-HTBackgroundPool -Async) } catch { Write-Log -Message "Przygotowanie operacji w tle: $($_.Exception.Message)" -Type 'Warn' }
}

function Test-HTBackgroundAvailable {
    param([string]$Service = '')
    if (-not $Global:BackgroundQueries -or $script:Background.Disabled) { return $false }
    if ($Service -eq 'Graph') { return ([bool]$Global:ConnectedToGraphAPI -and [bool](Get-Module -Name Microsoft.Graph.Authentication)) }
    return (-not $Service)
}

function Test-HTBackgroundAuthError {
    param($ErrorRecord)
    $text = "$($ErrorRecord.Exception.Message) $($ErrorRecord.Exception.InnerException.Message)"
    return ($text -match 'HTBackgroundUnavailable|Authentication needed|Connect-MgGraph|not connected|no.*context|InteractiveBrowserCredential|Nie zalogowano')
}

function Write-HTForwardedLog {
    # Wpis dziennika z wątku w tle - zapis w pliku i panelu dziennika okna
    param($Entry)
    if (-not $Entry) { return }
    $message = ([string]$Entry.Message -replace '^(ℹ️|⚠️|❌)\s*', '')
    $type = [string]$Entry.Type
    if ($type -notin 'Info', 'Warn', 'Error') { $type = 'Info' }
    if ($Entry.Notify) { $type += '&Notification' }
    Write-Log -Message $message -Type $type
}

function Set-HTCancelVisible([bool]$Visible) {
    # «Przerwij» na pasku stanu i obok wskaźnika pracy w nagłówku modułu
    $state = if ($Visible) { 'Visible' } else { 'Collapsed' }
    $b = $script:UI.Controls['btnCancelOps']
    if ($b) { $b.Visibility = $state }
    $m = $script:UI.ActiveModule
    if ($m -and $m.View_ -and $m.View_['btnBusyStop']) { $m.View_.btnBusyStop.Visibility = $state }
}

function Hide-HTCancelIfIdle {
    # Ukrywa «Przerwij», gdy nic już nie trwa (zapytanie w tle, pętla po obiektach) - po dłuższym poleceniu Exchange
    if (-not $script:Background.Current -and -not [int]$script:UI.StoppableDepth) { Set-HTCancelVisible $false }
}

function Start-HTStoppable {
    # Operacja na wielu obiektach w wątku okna: «Przerwij» (albo Esc) zatrzymuje ją po bieżącym obiekcie
    $script:UI.StoppableDepth = [int]$script:UI.StoppableDepth + 1
    if ($script:UI.StoppableDepth -eq 1) { $script:UI.StopRequested = $false }
    Set-HTCancelVisible $true
}

function Stop-HTStoppable {
    $script:UI.StoppableDepth = [Math]::Max(0, [int]$script:UI.StoppableDepth - 1)
    if ($script:UI.StoppableDepth -eq 0) {
        $script:UI.StopRequested = $false
        if (-not $script:Background.Current) { Set-HTCancelVisible $false }
    }
}

function Test-HTStopRequested {
    # Czy użytkownik kliknął «Przerwij» w trakcie operacji na wielu obiektach
    return ([bool]$script:UI.StopRequested -and [int]$script:UI.StoppableDepth -gt 0)
}

function Stop-HTBackground {
    # «Przerwij» (pasek stanu, nagłówek modułu, Esc): zapytanie w tle - od razu; operacja na wielu obiektach - po bieżącym obiekcie
    if ([int]$script:UI.StoppableDepth -gt 0 -and -not $script:UI.StopRequested) {
        $script:UI.StopRequested = $true
        Write-Log -Message 'Przerywanie operacji - zatrzyma się po bieżącym obiekcie…' -Type 'Info'
        Set-HTStatus -Text 'Przerywanie… (po bieżącym obiekcie)'
    }
    # Polecenie Exchange / SharePoint w wątku usługi (ServiceWorker) - zatrzymanie od razu
    $stopService = Get-Command -Name Stop-HTServiceWorkerCommand -ErrorAction Ignore
    if ($stopService -and (& $stopService)) { Write-Log -Message 'Przerywanie polecenia Exchange / SharePoint…' -Type 'Info' }
    $ps = $script:Background.Current
    if (-not $ps) { return }
    Write-Log -Message 'Przerywanie operacji w tle…' -Type 'Info'
    try { [void]$ps.BeginStop($null, $null) } catch { Write-Verbose $_ }
}

function Invoke-HTBackground {
    <#
        Wykonuje blok w wątku w tle i czeka na wynik, przetwarzając w tym czasie zdarzenia okna. -OnItem { param($item) }:
        każdy zwrócony obiekt od razu (np. dopisanie wierszy); bez -OnItem - zwraca wszystkie obiekty. Write-Progress w bloku
        aktualizuje pasek stanu. Przerwanie: OperationCanceledException; błąd bloku - wyjątek z jego komunikatem.
    #>
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock, [hashtable]$Arguments = @{}, [scriptblock]$OnItem, [string]$Name = 'Operacja')
    try { $pool = Get-HTBackgroundPool }
    catch {
        # Moduły nie wczytały się w wątku w tle - zapytania wracają do wątku okna
        $script:Background.Disabled = $true
        throw (New-Object System.InvalidOperationException("HTBackgroundUnavailable: $($_.Exception.Message)"))
    }
    $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($script:BackgroundWorker).AddArgument($ScriptBlock.ToString()).AddArgument($Arguments).AddArgument((Get-HTBackgroundGlobals)).AddArgument($queue)
    $inputData = New-Object 'System.Management.Automation.PSDataCollection[psobject]'
    $inputData.Complete()
    $output = New-Object 'System.Management.Automation.PSDataCollection[psobject]'
    $handle = $ps.BeginInvoke($inputData, $output)
    $bg = $script:Background
    $previous = $bg.Current
    $bg.Current = $ps
    Set-HTCancelVisible $true
    $results = New-Object System.Collections.Generic.List[object]
    $read = 0
    $progressRead = 0
    $drain = {
        while ($read -lt $output.Count) {
            $item = $output[$read]
            $read++
            if ($OnItem) { & $OnItem $item } else { $results.Add($item) }
        }
        $entry = $null
        while ($queue.TryDequeue([ref]$entry)) { Write-HTForwardedLog $entry }
        $progress = $ps.Streams.Progress
        if ($progress.Count -gt $progressRead) {
            $record = $progress[$progress.Count - 1]
            $progressRead = $progress.Count
            $status = if ($record.StatusDescription -and $record.StatusDescription -ne 'Processing') { "$Name - $($record.StatusDescription)" } else { $Name }
            if ($record.PercentComplete -ge 0) { Set-HTProgress -Value $record.PercentComplete -Maximum 100 -Text $status } else { Set-HTStatus -Text $status }
        }
    }
    try {
        while (-not $handle.IsCompleted) {
            . $drain
            Update-HTUi
            Start-Sleep -Milliseconds 40
        }
        . $drain
        try { [void]$ps.EndInvoke($handle) }
        catch [System.Management.Automation.PipelineStoppedException] { throw (New-Object System.OperationCanceledException("Przerwano: $Name")) }
        catch {
            $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException } else { $_.Exception }
            throw $inner
        }
        . $drain
        if ("$($ps.InvocationStateInfo.State)" -eq 'Stopped') { throw (New-Object System.OperationCanceledException("Przerwano: $Name")) }
        foreach ($err in @($ps.Streams.Error)) { Write-Log -Message "$($Name): $($err.Exception.Message)" -Type 'Warn' }
        # Ostrzeżenia poleceń z wątku w tle - do dziennika (bez powtórzeń)
        foreach ($line in @(Group-HTWarningMessages -Messages @($ps.Streams.Warning | ForEach-Object { $_.Message }))) { Write-Log -Message "Ostrzeżenie ($Name): $line" -Type 'Warn' }
    }
    finally {
        $bg.Current = $previous
        if (-not $previous -and -not [int]$script:UI.StoppableDepth) { Set-HTCancelVisible $false }
        $ps.Dispose()
    }
    if (-not $OnItem) { return $results.ToArray() }
}

function Close-HTBackground {
    # Zamknięcie programu: zatrzymanie zadań i zwolnienie puli wątków
    $bg = $script:Background
    if ($bg.Timer) { $bg.Timer.Stop() }
    foreach ($task in @($bg.Tasks)) { try { $task.PS.Stop(); $task.PS.Dispose(); $task.Runspace.Dispose() } catch { Write-Verbose $_ } }
    $bg.Tasks.Clear()
    if ($bg.Pool) { try { $bg.Pool.Dispose() } catch { Write-Verbose $_ } }
    $bg.Pool = $null
    $bg.PoolModules = ''
}

function Start-HTBackgroundTask {
    <#
        Zadanie w tle bez czekania (np. sprawdzenie aktualizacji przy starcie): -OnComplete { param($Result, $ErrorMessage) }
        wywoływane w wątku okna po zakończeniu. Osobny wątek z wybranymi modułami (-Modules).
    #>
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock, [hashtable]$Arguments = @{}, [scriptblock]$OnComplete, [string[]]$Modules = @('Utils', 'Security', 'Integrations'))
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    $iss.ImportPSModule([string[]](Get-HTBackgroundModulePaths -Names $Modules -NoGraph))
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    [void]$ps.AddScript($script:BackgroundWorker).AddArgument($ScriptBlock.ToString()).AddArgument($Arguments).AddArgument((Get-HTBackgroundGlobals)).AddArgument($queue)
    $task = @{ PS = $ps; Runspace = $rs; Handle = $ps.BeginInvoke(); OnComplete = $OnComplete; Queue = $queue }
    [void]$script:Background.Tasks.Add($task)
    if (-not $script:Background.Timer) {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromMilliseconds(400)
        $t.add_Tick({
                param($s, $e)
                foreach ($task in @($script:Background.Tasks)) {
                    $entry = $null
                    while ($task.Queue.TryDequeue([ref]$entry)) { Write-HTForwardedLog $entry }
                    if (-not $task.Handle.IsCompleted) { continue }
                    [void]$script:Background.Tasks.Remove($task)
                    $result = $null
                    $message = ''
                    try { $result = @($task.PS.EndInvoke($task.Handle)) } catch { $message = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message } }
                    try { $task.PS.Dispose(); $task.Runspace.Dispose() } catch { Write-Verbose $_ }
                    if ($task.OnComplete) { try { & $task.OnComplete $result $message } catch { Write-Log -Message "Zadanie w tle: $($_.Exception.Message)" -Type 'Warn' } }
                }
                if ($script:Background.Tasks.Count -eq 0) { $s.Stop() }
            })
        $script:Background.Timer = $t
    }
    $script:Background.Timer.Start()
}
#endregion

#region Powiadomienie Windows po długiej operacji
$script:Notify = @{ Icon = $null; Timer = $null }

function Invoke-HTFlashWindow {
    # Miganie przycisku programu na pasku zadań (do aktywacji okna)
    param([Parameter(Mandatory)]$Window)
    try {
        if (-not ('HelpdeskTools.Flash' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace HelpdeskTools {
    public static class Flash {
        [StructLayout(LayoutKind.Sequential)]
        private struct FLASHWINFO { public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }
        [DllImport("user32.dll")]
        private static extern bool FlashWindowEx(ref FLASHWINFO info);
        public static void Start(IntPtr handle) {
            FLASHWINFO f = new FLASHWINFO();
            f.cbSize = (uint)Marshal.SizeOf(typeof(FLASHWINFO));
            f.hwnd = handle;
            f.dwFlags = 3 | 12;
            f.uCount = 5;
            f.dwTimeout = 0;
            FlashWindowEx(ref f);
        }
    }
}
'@ -ErrorAction Stop
        }
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $Window).Handle
        if ($hwnd -ne [IntPtr]::Zero) { [HelpdeskTools.Flash]::Start($hwnd) }
    }
    catch { Write-Verbose "Miganie okna: $_" }
}

function Show-HTWindowsNotification {
    # Dymek w obszarze powiadomień Windows (kliknięcie przywraca okno programu) i miganie paska zadań
    param([Parameter(Mandatory)][string]$Text, [int]$Seconds = 0, [string]$Title = 'Helpdesk Tools')
    $main = $script:UI.Window
    if ($main) { Invoke-HTFlashWindow -Window $main }
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop
        $n = $script:Notify
        if (-not $n.Icon) {
            $icon = New-Object System.Windows.Forms.NotifyIcon
            $icon.Icon = if ($Global:AppIconPath -and (Test-Path -LiteralPath $Global:AppIconPath)) { New-Object System.Drawing.Icon($Global:AppIconPath) } else { [System.Drawing.SystemIcons]::Information }
            $icon.Text = 'Helpdesk Tools'
            $icon.add_BalloonTipClicked({ try { $w = $script:UI.Window; if ($w) { if ($w.WindowState -eq 'Minimized') { $w.WindowState = 'Normal' }; [void]$w.Activate() } } catch { Write-Verbose $_ } })
            $icon.add_Click({ try { $w = $script:UI.Window; if ($w) { [void]$w.Activate() } } catch { Write-Verbose $_ } })
            $n.Icon = $icon
        }
        $n.Icon.Visible = $true
        $n.Icon.BalloonTipTitle = $Title
        $n.Icon.BalloonTipText = $Text + $(if ($Seconds) { " ($Seconds s)" } else { '' })
        $n.Icon.ShowBalloonTip(10000)
        if (-not $n.Timer) {
            $t = New-Object System.Windows.Threading.DispatcherTimer
            $t.Interval = [TimeSpan]::FromSeconds(20)
            $t.add_Tick({ param($s, $e) $s.Stop(); try { $script:Notify.Icon.Visible = $false } catch { Write-Verbose $_ } })
            $n.Timer = $t
        }
        $n.Timer.Stop()
        $n.Timer.Start()
    }
    catch { Write-Verbose "Powiadomienie Windows: $_" }
}

function Remove-HTWindowsNotification {
    # Usunięcie ikony z obszaru powiadomień przy zamykaniu programu
    try { if ($script:Notify.Icon) { $script:Notify.Icon.Visible = $false; $script:Notify.Icon.Dispose(); $script:Notify.Icon = $null } } catch { Write-Verbose $_ }
}
#endregion

#region Eksport i wysyłka wyników, zapisane widoki filtrów
function Get-HTResultExportData {
    # Widoczne wiersze i kolumny modułu do eksportu: kolumny, wiersze (słowniki z __flag) i opis (moduł, filtry)
    param([Parameter(Mandatory)][hashtable]$Module)
    $columns = @(Get-HTVisibleColumnNames -Module $Module)
    $rows = @($Module.View | ForEach-Object { $_ })
    $data = @(foreach ($r in $rows) {
            $o = [ordered]@{}
            foreach ($c in $columns) { $v = Get-HTExportValue -Module $Module -Row $r -Column $c; $o[$c] = if ($null -eq $v -or $v -is [System.DBNull]) { '' } else { $v } }
            $o['__flag'] = [string](Get-HTObjectValue $r '__flag')
            $o
        })
    $filter = if ($Module.FilterBox) { $Module.FilterBox.Text.Trim() } else { '' }
    $meta = [ordered]@{
        'Moduł'        = $Module.Title
        'Przestrzeń'   = $Module.WorkspaceTitle
        'Data'         = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        'Użytkownik'   = "$env:USERDOMAIN\$env:USERNAME$(if ($Global:HTActiveAccount) { " ($($Global:HTActiveAccount))" })"
        'Wiersze'      = $rows.Count
        'Program'      = "Helpdesk Tools $($Global:AppVersion)"
    }
    if ($filter) { $meta['Filtr'] = $filter }
    if ($Module.ColumnFilters.Count -gt 0) { $meta['Filtry kolumn'] = Get-HTColumnFiltersText -Module $Module }
    $metaText = '{0}{1} • {2} • {3} • wierszy: {4}' -f $(if ($Module.WorkspaceTitle) { "$($Module.WorkspaceTitle) • " } else { '' }), $meta.Program, $meta.Data, $env:USERNAME, $rows.Count
    if ($filter) { $metaText += " • filtr: $filter" }
    if ($Module.ColumnFilters.Count -gt 0) { $metaText += ' • filtry kolumn: ' + $meta['Filtry kolumn'] }
    return @{ Title = $Module.Title; Columns = $columns; Rows = $data; Meta = $meta; MetaText = $metaText; Secrets = ($Module.RevealSecrets -and $Module.SecretColumns.Count -gt 0) }
}

function Save-HTResultFile {
    # Zapis danych eksportu w formacie wg rozszerzenia: .xlsx, .html, .json, .csv
    param([Parameter(Mandatory)][hashtable]$Data, [Parameter(Mandatory)][string]$Path)
    $plain = { @($Data.Rows | ForEach-Object { $o = [ordered]@{}; foreach ($c in $Data.Columns) { $o[$c] = [string]$_[$c] }; [PSCustomObject]$o }) }
    switch -Regex ($Path) {
        '\.xlsx$' { [void](Export-HTXlsx -Path $Path -Columns $Data.Columns -Rows $Data.Rows -SheetName $Data.Title -Meta $Data.Meta) }
        '\.html?$' { [System.IO.File]::WriteAllText($Path, (ConvertTo-HTHtmlReport -Title $Data.Title -Columns $Data.Columns -Rows $Data.Rows -Meta $Data.MetaText), (New-Object System.Text.UTF8Encoding($true))) }
        '\.json$' { [System.IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject @(& $plain) -Depth 4), (New-Object System.Text.UTF8Encoding($false))) }
        default { @(& $plain) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8BOM -Delimiter ';' }
    }
}

function Export-HTResultView {
    # Eksport widocznych wierszy i kolumn: Excel, CSV (Excel), raport HTML (wyszukiwarka, sortowanie, filtry kolumn) albo JSON
    param([hashtable]$Module)
    $data = Get-HTResultExportData -Module $Module
    if ($data.Columns.Count -eq 0 -or $data.Rows.Count -eq 0) { Show-HTMessage -Text 'Brak wyników do eksportu.' -Title 'Eksport'; return }
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = 'Eksport wyników'
    $dialog.Filter = 'Excel (*.xlsx)|*.xlsx|CSV - Excel (*.csv)|*.csv|Raport HTML (*.html)|*.html|JSON (*.json)|*.json'
    $dialog.InitialDirectory = Get-HTExportDirectory
    $dialog.FileName = '{0}_{1:yyyy-MM-dd_HH-mm}' -f ($Module.Title -replace '[^\w\-]+', '_'), (Get-Date)
    $dialog.AddExtension = $true
    $dialog.DefaultExt = '.xlsx'
    $owner = $script:UI.Window
    $accepted = if ($owner -and $owner.IsVisible) { $dialog.ShowDialog($owner) } else { $dialog.ShowDialog() }
    if ($accepted -ne $true) { return }
    try {
        Save-HTResultFile -Data $data -Path $dialog.FileName
        Write-Log -Message "Zapisano $($data.Rows.Count) wierszy ($($Module.Title)) do pliku: $($dialog.FileName)" -Type 'Info&Notification'
    }
    catch {
        Write-Log -Message "Błąd zapisu eksportu: $($_.Exception.Message)" -Type 'Error'
        Show-HTError 'Nie zapisano pliku eksportu.' $_
    }
}

function Select-HTOpenFile {
    # Okno wyboru pliku do odczytu; zwraca ścieżkę albo $null
    param([string]$Title = 'Wybierz plik', [string]$Filter = 'Wszystkie pliki (*.*)|*.*', [string]$InitialDirectory = '')
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    if ($InitialDirectory -and (Test-Path -LiteralPath $InitialDirectory)) { $dialog.InitialDirectory = $InitialDirectory }
    $owner = $script:UI.Window
    $accepted = if ($owner -and $owner.IsVisible) { $dialog.ShowDialog($owner) } else { $dialog.ShowDialog() }
    if ($accepted -eq $true) { return $dialog.FileName }
    return $null
}

function Select-HTFolder {
    # Okno wyboru folderu na dysku (WPF w .NET 8, wcześniej Windows Forms); zwraca ścieżkę albo $null
    param([string]$Title = 'Wybierz folder')
    if ('Microsoft.Win32.OpenFolderDialog' -as [type]) {
        $dialog = New-Object -TypeName 'Microsoft.Win32.OpenFolderDialog'
        $dialog.Title = $Title
        $owner = $script:UI.Window
        $accepted = if ($owner -and $owner.IsVisible) { $dialog.ShowDialog($owner) } else { $dialog.ShowDialog() }
        if ($accepted -eq $true) { return $dialog.FolderName }
        return $null
    }
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = $Title
    $browser.ShowNewFolderButton = $false
    if ($browser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $browser.SelectedPath }
    return $null
}

function Select-HTSaveFile {
    # Okno zapisu pliku (domyślnie katalog eksportu); zwraca ścieżkę albo $null
    param([string]$Title = 'Zapisz plik', [string]$Filter = 'Wszystkie pliki (*.*)|*.*', [string]$FileName = '', [string]$DefaultExt = '')
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    $dialog.InitialDirectory = Get-HTExportDirectory
    $dialog.FileName = $FileName
    if ($DefaultExt) { $dialog.AddExtension = $true; $dialog.DefaultExt = $DefaultExt }
    $owner = $script:UI.Window
    $accepted = if ($owner -and $owner.IsVisible) { $dialog.ShowDialog($owner) } else { $dialog.ShowDialog() }
    if ($accepted -eq $true) { return $dialog.FileName }
    return $null
}

function Send-HTResultMail {
    # Widoczne wyniki e-mailem z konta zalogowanego w Microsoft 365 (uprawnienie Mail.Send)
    param([Parameter(Mandatory)][hashtable]$Module)
    $data = Get-HTResultExportData -Module $Module
    if ($data.Rows.Count -eq 0) { Show-HTMessage -Text 'Brak wyników do wysłania.' -Title 'Wyślij e-mailem'; return }
    if ($data.Secrets -and -not (Show-HTConfirm -Warning -Title 'Dane poufne' -ConfirmText 'Wyślij mimo to' -Message 'Wyniki zawierają odkryte dane poufne (np. hasła). Wysłać je e-mailem? Bezpieczniej wyłączyć «Pokaż poufne» przed wysyłką.')) { return }
    if (-not (Assert-HTGraphScopes -Scopes @('Mail.Send') -Feature 'Wysyłka wyników e-mailem')) { return }
    $formats = @('Excel (.xlsx)', 'Raport HTML (.html)', 'CSV (.csv)', 'Tabela w treści wiadomości')
    $form = Show-HTFormDialog -Title 'Wyślij wyniki e-mailem' -Description "$($Module.Title): $($data.Rows.Count) wierszy. Wiadomość zostanie wysłana z Twojej skrzynki." -Icon 'E715' -OkText 'Wyślij' -Fields @(
        @{ Name = 'To'; Label = 'Odbiorcy (adresy e-mail - przecinek, średnik lub nowa linia)'; Type = 'Multiline'; Required = $true; Height = 60 }
        @{ Name = 'Subject'; Label = 'Temat'; Required = $true; Default = "$($Module.Title) - $((Get-Date).ToString('yyyy-MM-dd HH:mm'))" }
        @{ Name = 'Format'; Label = 'Wyniki'; Type = 'Combo'; Options = $formats }
        @{ Name = 'Message'; Label = 'Wiadomość (opcjonalnie)'; Type = 'Multiline'; Height = 70 }
    )
    if (-not $form) { return }
    $to = @(Split-HTInputList $form.To)
    $intro = if ($form.Message) { '<p>' + ((ConvertTo-HTHtmlText $form.Message) -replace "`r?`n", '<br>') + '</p>' } else { '' }
    $info = "<p style=`"color:#666`">$(ConvertTo-HTHtmlText $data.MetaText)</p>"
    $attachments = @()
    $safeName = ($Module.Title -replace '[^\w\-]+', '_')
    Set-HTBusy -Busy $true -Text 'Wysyłanie wiadomości…'
    try {
        switch ($form.Format) {
            'Raport HTML (.html)' {
                $html = ConvertTo-HTHtmlReport -Title $data.Title -Columns $data.Columns -Rows $data.Rows -Meta $data.MetaText
                $attachments += New-HTMailAttachment -Name "$safeName.html" -Bytes ([System.Text.Encoding]::UTF8.GetPreamble() + [System.Text.Encoding]::UTF8.GetBytes($html)) -ContentType 'text/html'
            }
            'CSV (.csv)' {
                $csv = (@($data.Rows | ForEach-Object { $o = [ordered]@{}; foreach ($c in $data.Columns) { $o[$c] = [string]$_[$c] }; [PSCustomObject]$o }) | ConvertTo-Csv -NoTypeInformation -Delimiter ';') -join "`r`n"
                $attachments += New-HTMailAttachment -Name "$safeName.csv" -Bytes ([System.Text.Encoding]::UTF8.GetPreamble() + [System.Text.Encoding]::UTF8.GetBytes($csv)) -ContentType 'text/csv'
            }
            'Tabela w treści wiadomości' {
                $shown = @($data.Rows | Select-Object -First 300)
                $table = New-Object System.Text.StringBuilder
                [void]$table.Append('<table style="border-collapse:collapse;font:13px Segoe UI,sans-serif"><tr>')
                foreach ($c in $data.Columns) { [void]$table.Append('<th style="background:#3E6FE0;color:#fff;padding:4px 8px;text-align:left">').Append((ConvertTo-HTHtmlText $c)).Append('</th>') }
                [void]$table.Append('</tr>')
                foreach ($r in $shown) {
                    $bg = switch ([string]$r['__flag']) { 'crit' { '#FDE2E4' } 'warn' { '#FFF4D6' } default { '#FFFFFF' } }
                    [void]$table.Append("<tr style=`"background:$bg`">")
                    foreach ($c in $data.Columns) { [void]$table.Append('<td style="border:1px solid #D9DEE7;padding:3px 8px">').Append((ConvertTo-HTHtmlText $r[$c])).Append('</td>') }
                    [void]$table.Append('</tr>')
                }
                [void]$table.Append('</table>')
                if ($data.Rows.Count -gt $shown.Count) { [void]$table.Append("<p>Pokazano $($shown.Count) z $($data.Rows.Count) wierszy - pełne dane w eksporcie do Excela.</p>") }
                $info += $table.ToString()
            }
            default {
                $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("HelpdeskTools_" + [guid]::NewGuid().ToString('N') + '.xlsx')
                try {
                    [void](Export-HTXlsx -Path $tmp -Columns $data.Columns -Rows $data.Rows -SheetName $data.Title -Meta $data.Meta)
                    $attachments += New-HTMailAttachment -Name "$safeName.xlsx" -Bytes ([System.IO.File]::ReadAllBytes($tmp)) -ContentType 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                }
                finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
            }
        }
        $body = "<div style=`"font:14px Segoe UI,sans-serif`">$intro<p><b>$(ConvertTo-HTHtmlText $data.Title)</b> - wierszy: $($data.Rows.Count)$(if ($attachments.Count) { ' (w załączniku)' }).</p>$info</div>"
        Send-HTGraphMail -To $to -Subject $form.Subject -HtmlBody $body -Attachments $attachments
        Add-HTOperationRecord -Operation 'Wysyłka wyników e-mailem' -Object ($to -join ', ') -Details $form.Subject -Module $Module.Title
        Show-HTToast "Wysłano do: $($to -join ', ')" 'ok'
    }
    catch {
        Write-Log -Message "Wysyłka wyników e-mailem: $($_.Exception.Message)" -Type 'Error'
        Show-HTError 'Nie wysłano wiadomości.' $_
    }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
}

function Set-HTFilterPresetView {
    # Zastosowanie zapisanego widoku: filtr tekstowy, filtry kolumn i ukryte kolumny
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)]$Preset)
    $Module.ColumnFilters.Clear()
    foreach ($f in @($Preset.Filters)) {
        if (-not $f -or -not $f.Column) { continue }
        $values = $null
        if ($null -ne $f.Values) { $values = [string[]]@($f.Values) }
        [void](Set-HTColumnFilterEntry -Module $Module -Column ([string]$f.Column) -Values $values -Op ([string]$f.Op) -Text ([string]$f.Text))
    }
    $Module.UserHidden.Clear()
    foreach ($h in @($Preset.Hidden)) { if ($h) { [void]$Module.UserHidden.Add([string]$h) } }
    foreach ($c in @($Module.Grid.Columns)) { $c.Visibility = if ($Module.UserHidden.Contains([string]$c.SortMemberPath)) { 'Collapsed' } else { 'Visible' } }
    $Module['ActiveView'] = $null
    Update-HTColumnsButton -Module $Module
    if ($Module.FilterBox) { $Module.FilterBox.Text = [string]$Preset.Text }
    # Widok zapisany (nie «domyślny» z «Wyczyść filtry») - przycisk podświetlony z nazwą do ręcznej zmiany
    if ($Preset.Name -and [string]$Preset.Name -ne 'domyślny') { $Module['ActiveView'] = @{ Name = [string]$Preset.Name; Signature = (Get-HTViewSignature -Module $Module) } }
    Update-HTColumnFilterState -Module $Module
    Show-HTToast "Widok: $($Preset.Name)" 'info' 2
}

function Show-HTViewsMenu {
    # Menu zapisanych widoków modułu (przycisk nad tabelą wyników)
    param([Parameter(Mandatory)][hashtable]$Module, $Anchor)
    $menu = New-Object System.Windows.Controls.ContextMenu
    $presets = @(Get-HTFilterPresets $Module.Key)
    foreach ($p in $presets) {
        [void]$menu.Items.Add((New-HTMenuItem -Text ([string]$p.Name) -Icon 'E71D' -Module $Module -Data $p -Action { param($m, $s) Set-HTFilterPresetView -Module $m -Preset $s.Tag.Data }))
    }
    if ($presets.Count) { [void]$menu.Items.Add((New-HTMenuSeparator)) }
    [void]$menu.Items.Add((New-HTMenuItem -Text 'Zapisz bieżący widok…' -Icon 'E74E' -Module $Module -Action {
                param($m)
                $name = Show-InputBox -Title 'Zapisz widok' -Prompt "Nazwa widoku dla modułu «$($m.Title)» (filtr, filtry kolumn i ukryte kolumny):" -Icon 'E71D'
                if (-not $name) { return }
                $preset = ConvertTo-HTFilterPreset -Name $name -Text $(if ($m.FilterBox) { $m.FilterBox.Text } else { '' }) -ColumnFilters $m.ColumnFilters -Hidden @($m.UserHidden)
                Save-HTFilterPreset -Key $m.Key -Preset $preset
                Show-HTToast "Zapisano widok «$name»." 'ok'
            }))
    if ($presets.Count) {
        [void]$menu.Items.Add((New-HTMenuItem -Text 'Usuń widok…' -Icon 'E74D' -Module $Module -Action {
                    param($m)
                    $names = @(Get-HTFilterPresets $m.Key | ForEach-Object { [string]$_.Name })
                    $chosen = @(Show-HTSelectionDialog -Title 'Usuń widoki' -Items $names -MultiSelect -OkText 'Usuń' -Icon 'E74D')
                    foreach ($n in $chosen) { if ($n) { Remove-HTFilterPreset -Key $m.Key -Name $n } }
                    if ($chosen.Count) { Show-HTToast "Usunięto widoki: $($chosen.Count)" 'ok' }
                }))
    }
    [void]$menu.Items.Add((New-HTMenuItem -Text 'Wyczyść filtry i pokaż wszystkie kolumny' -Icon 'E894' -Module $Module -Action {
                param($m)
                Set-HTFilterPresetView -Module $m -Preset @{ Name = 'domyślny'; Text = ''; Filters = @(); Hidden = @() }
            }))
    if ($Anchor) {
        $menu.PlacementTarget = $Anchor
        $menu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
    }
    $menu.IsOpen = $true
}
#endregion

#region Paleta poleceń (Ctrl+K): moduły, ulubione, ostatnie, polecenia
$script:PaletteActions = New-Object System.Collections.ArrayList

function Register-HTPaletteAction {
    <#
        Polecenie palety. -NeedsQuery: polecenie z wpisanym tekstem (np. «Wizytówka użytkownika: <tekst>») - pokazywane,
        gdy wpisano co najmniej 2 znaki; -Action { param($Query) }. Bez -NeedsQuery: polecenie pokazywane według nazwy.
    #>
    param([Parameter(Mandatory)][string]$Text, [string]$Icon = 'E76C', [string]$Description = '', [Parameter(Mandatory)][scriptblock]$Action, [switch]$NeedsQuery, [string]$Keywords = '')
    [void]$script:PaletteActions.Add(@{ Text = $Text; Icon = $Icon; Description = $Description; Action = $Action; NeedsQuery = [bool]$NeedsQuery; Keywords = $Keywords })
}

function Get-HTPaletteItems {
    # Pozycje palety dla wpisanego tekstu (bez tekstu: ulubione, ostatnie i polecenia)
    param([AllowEmptyString()][string]$Query = '')
    $q = $Query.Trim()
    $items = New-Object System.Collections.Generic.List[object]
    $defs = @($script:UI.ModuleDefs | Where-Object { $script:UI.Workspaces.Contains($_.Workspace) -and (Test-HTModuleAllowed $_.Key) -and (Test-HTWorkspaceAllowed $_.Workspace) })
    $state = Get-HTUiState
    $newItem = {
        param($d, [string]$Prefix)
        $ws = $script:UI.Workspaces[$d.Workspace]
        @{ Kind = 'Module'; Key = $d.Key; Icon = $d.Icon; Title = $d.Title; Sub = "$Prefix$($ws.Title) • $($d.Category)"; Star = (Test-HTFavoriteModule $d.Key) }
    }
    if (-not $q) {
        foreach ($key in @($state.Favorites)) { $d = @($defs | Where-Object { $_.Key -eq $key })[0]; if ($d) { $items.Add((& $newItem $d 'Ulubione • ')) } }
        foreach ($key in @($state.Recent | Select-Object -First 8)) {
            if (@($state.Favorites) -contains $key) { continue }
            $d = @($defs | Where-Object { $_.Key -eq $key })[0]
            if ($d) { $items.Add((& $newItem $d 'Ostatnio • ')) }
        }
        foreach ($a in $script:PaletteActions) { if (-not $a.NeedsQuery) { $items.Add(@{ Kind = 'Action'; Action = $a; Icon = $a.Icon; Title = $a.Text; Sub = $a.Description; Star = $false }) } }
        return $items.ToArray()
    }
    $words = @($q.ToLowerInvariant() -split '\s+' | Where-Object { $_ })
    $scored = foreach ($d in $defs) {
        $ws = $script:UI.Workspaces[$d.Workspace]
        $hay = "$($d.Title) $($ws.Title) $($d.Category) $($d.Description) $($d.Key)".ToLowerInvariant()
        $all = $true
        foreach ($w in $words) { if (-not $hay.Contains($w)) { $all = $false; break } }
        if (-not $all) { continue }
        $title = "$($d.Title)".ToLowerInvariant()
        $score = if ($title.StartsWith($q.ToLowerInvariant())) { 0 } elseif ($title.Contains($words[0])) { 1 } else { 2 }
        if (Test-HTFavoriteModule $d.Key) { $score -= 0.5 }
        [PSCustomObject]@{ Score = $score; Def = $d }
    }
    foreach ($s in @($scored | Sort-Object Score, @{ Expression = { $_.Def.Title } } | Select-Object -First 25)) { $items.Add((& $newItem $s.Def '')) }
    foreach ($a in $script:PaletteActions) {
        if ($a.NeedsQuery) {
            if ($q.Length -ge 2) { $items.Add(@{ Kind = 'Action'; Action = $a; Query = $q; Icon = $a.Icon; Title = "$($a.Text): «$q»"; Sub = $a.Description; Star = $false }) }
            continue
        }
        $hay = "$($a.Text) $($a.Keywords) $($a.Description)".ToLowerInvariant()
        $all = $true
        foreach ($w in $words) { if (-not $hay.Contains($w)) { $all = $false; break } }
        if ($all) { $items.Add(@{ Kind = 'Action'; Action = $a; Icon = $a.Icon; Title = $a.Text; Sub = $a.Description; Star = $false }) }
    }
    return $items.ToArray()
}

$script:PaletteXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="660" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" WindowStartupLocation="CenterOwner" Foreground="#E4E8EF" FontFamily="Segoe UI" FontSize="13"
        UseLayoutRounding="True" SnapsToDevicePixels="True" TextOptions.TextFormattingMode="Display">
  <Border Background="#161B22" BorderBrush="#2F3846" BorderThickness="1" CornerRadius="12" Margin="18" Padding="14,12,14,10">
    <Border.Effect><DropShadowEffect BlurRadius="26" ShadowDepth="4" Opacity="0.55" Color="Black"/></Border.Effect>
    <StackPanel>
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
        <TextBlock Style="{StaticResource Glyph}" Text="&#xE721;" FontSize="16" Foreground="#8CB0FF" VerticalAlignment="Center" Margin="4,0,12,0"/>
        <TextBox x:Name="plQuery" Grid.Column="1" FontSize="15" Tag="Szukaj modułów i poleceń (np. licencje, skrzynka, MFA)…"/>
      </Grid>
      <ListBox x:Name="plList" Margin="0,10,0,0" MaxHeight="440" Background="Transparent" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
      <TextBlock x:Name="plHint" Foreground="#5E6779" FontSize="11.5" Margin="4,8,0,0" TextWrapping="Wrap"
                 Text="↑ ↓ wybór • Enter otwórz • Esc zamknij • prawy przycisk na module w nawigacji - dodaj do ulubionych"/>
    </StackPanel>
  </Border>
</Window>
'@

$script:PaletteEvents = @{
    Query       = { param($s, $e) Update-HTPaletteList -Window ([System.Windows.Window]::GetWindow($s)) }
    KeyDown     = {
        param($s, $e)
        $list = $s.FindName('plList')
        switch ([string]$e.Key) {
            'Down' { if ($list.Items.Count) { $list.SelectedIndex = [Math]::Min($list.Items.Count - 1, $list.SelectedIndex + 1); $list.ScrollIntoView($list.SelectedItem) }; $e.Handled = $true }
            'Up' { if ($list.Items.Count) { $list.SelectedIndex = [Math]::Max(0, $list.SelectedIndex - 1); $list.ScrollIntoView($list.SelectedItem) }; $e.Handled = $true }
            'Return' { Complete-HTPalette -Window $s; $e.Handled = $true }
            'Escape' { $s.Tag.Closing = $true; Close-HTDialog -Window $s -Ok $false; $e.Handled = $true }
        }
    }
    Click       = { param($s, $e) Complete-HTPalette -Window ([System.Windows.Window]::GetWindow($s)) }
    Deactivated = { param($s, $e) if (-not $s.Tag.Closing) { $s.Tag.Closing = $true; try { Close-HTDialog -Window $s -Ok $false } catch { Write-Verbose $_ } } }
}

function Update-HTPaletteList {
    param([Parameter(Mandatory)]$Window)
    $list = $Window.FindName('plList')
    $list.Items.Clear()
    foreach ($item in @(Get-HTPaletteItems -Query $Window.FindName('plQuery').Text)) {
        $li = New-Object System.Windows.Controls.ListBoxItem
        $li.Tag = $item
        $li.Padding = '8,6'
        $grid = New-Object System.Windows.Controls.Grid
        foreach ($width in 'Auto', '*', 'Auto') {
            $cd = New-Object System.Windows.Controls.ColumnDefinition
            $cd.Width = if ($width -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
            [void]$grid.ColumnDefinitions.Add($cd)
        }
        $icon = New-HTGlyphBlock -Code $(if ($item.Icon) { $item.Icon } else { 'E76C' }) -Size 15 -Color $(if ($item.Kind -eq 'Action') { '#5EE3AE' } else { '#8CB0FF' })
        $icon.Margin = '2,0,12,0'
        $icon.Width = 20
        $icon.VerticalAlignment = 'Center'
        [void]$grid.Children.Add($icon)
        $texts = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = [string]$item.Title
        $t1.FontWeight = 'SemiBold'
        $t1.TextTrimming = 'CharacterEllipsis'
        [void]$texts.Children.Add($t1)
        if ($item.Sub) {
            $t2 = New-Object System.Windows.Controls.TextBlock
            $t2.Text = [string]$item.Sub
            $t2.Foreground = Get-HTBrush '#8791A5'
            $t2.FontSize = 11.5
            $t2.TextTrimming = 'CharacterEllipsis'
            [void]$texts.Children.Add($t2)
        }
        [System.Windows.Controls.Grid]::SetColumn($texts, 1)
        [void]$grid.Children.Add($texts)
        if ($item.Star) {
            $star = New-HTGlyphBlock -Code 'E735' -Size 11 -Color '#FFC46B'
            $star.VerticalAlignment = 'Center'
            [System.Windows.Controls.Grid]::SetColumn($star, 2)
            [void]$grid.Children.Add($star)
        }
        $li.Content = $grid
        $li.add_MouseDoubleClick($script:PaletteEvents.Click)
        [void]$list.Items.Add($li)
    }
    if ($list.Items.Count) { $list.SelectedIndex = 0 }
}

function Complete-HTPalette {
    param([Parameter(Mandatory)]$Window)
    $selected = $Window.FindName('plList').SelectedItem
    if (-not $selected) { return }
    $Window.Tag.Choice = $selected.Tag
    $Window.Tag.Closing = $true
    Close-HTDialog -Window $Window -Ok $true
}

function Show-HTCommandPalette {
    # Ctrl+K: szybkie przejście do modułu albo polecenia; wybrana pozycja wykonuje się po zamknięciu palety
    $w = New-HTUiElement $script:PaletteXaml
    $w.Tag = @{ Result = $false; Modal = $false; Choice = $null; Closing = $false }
    $w.FindName('plQuery').add_TextChanged($script:PaletteEvents.Query)
    $w.add_PreviewKeyDown($script:PaletteEvents.KeyDown)
    $w.add_Deactivated($script:PaletteEvents.Deactivated)
    $w.add_ContentRendered({ param($s, $e) [void]$s.FindName('plQuery').Focus() })
    Update-HTPaletteList -Window $w
    [void](Invoke-HTDialog $w)
    $choice = $w.Tag.Choice
    if (-not $choice) { return }
    if ($choice.Kind -eq 'Module') { Invoke-HTUiAction -Module $null -Action { param($m, $key) Show-HTModule -Key $key } -Source $choice.Key; return }
    # Polecenie i tekst przekazane parametrem: zmienna «$action» w bloku wskazywałaby parametr -Action funkcji
    # Invoke-HTUiAction (ten sam moduł, PowerShell nie rozróżnia wielkości liter) - wtedy żadne polecenie palety nie działało
    Invoke-HTUiAction -Module $null -Action { param($m, $request) & $request.Run $request.Query } -Source @{ Run = $choice.Action.Action; Query = [string]$choice.Query }
}
#endregion

#region Podsumowanie operacji do zgłoszenia
$script:OperationSummaryXaml = @'
<StackPanel>
  <Grid Margin="0,0,0,8">
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
      <TextBox x:Name="osFilter" Width="320" Tag="Obiekt lub operacja (np. jan.kowalski)…"/>
      <CheckBox x:Name="osChecks" Content="Uwzględnij sprawdzenia" IsChecked="True" Margin="14,0,0,0"
                ToolTip="Co i gdzie zostało sprawdzone (zapytania, «Sprawdź stan») i z jakim wynikiem - przed zmianami"/>
    </StackPanel>
    <Border Style="{StaticResource Chip}" HorizontalAlignment="Right">
      <TextBlock x:Name="osCount" Foreground="#AEB6C4" FontSize="11.5"/>
    </Border>
  </Grid>
  <TextBox x:Name="osText" Style="{StaticResource MultiText}" IsReadOnly="True" Height="360" TextWrapping="Wrap"/>
  <TextBlock Foreground="#7B8496" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"
             Text="Sprawdzenia (co i gdzie sprawdzono, z jakim wynikiem) i zmiany wykonane w tej sesji programu, bez haseł i danych poufnych. Wklej tekst do zgłoszenia albo wyślij na kanał Teams."/>
</StackPanel>
'@

$script:OperationSummaryEvents = @{
    Filter = { param($s, $e) Update-HTOperationSummary -Window ([System.Windows.Window]::GetWindow($s)) }
    Copy   = {
        param($s, $e)
        $t = [System.Windows.Window]::GetWindow($s).FindName('osText').Text
        if ($t) { Set-HTClipboard $t; Show-HTToast 'Skopiowano podsumowanie.' 'ok' }
    }
    Teams  = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        $records = @($w.Tag.Records)
        if (-not $records.Count) { return }
        $facts = [ordered]@{}
        $groups = @($records | Group-Object { if ((Get-HTOperationKind $_) -eq 'Check') { "Sprawdzenie: $($_.Operation)" } else { $_.Operation } } | Select-Object -First 10)
        foreach ($g in $groups) { $facts[$g.Name] = (@($g.Group | ForEach-Object { if ((Get-HTOperationKind $_) -eq 'Check') { "$(if ($_.Object) { "$($_.Object): " })$($_.Details)" } else { "$($_.Object) ($($_.Status))" } }) -join ', ') }
        if (Send-HTTeamsMessage -Title 'Podsumowanie wykonanych czynności' -Text $w.FindName('osFilter').Text -Facts $facts -Tone 'ok' -Event 'Manual') { Show-HTToast 'Wysłano na kanał Teams.' 'ok' }
        else { Show-HTWarning 'Nie wysłano - ustaw adres webhooka Teams w Ustawieniach (sekcja «Teams i e-mail») i sprawdź dziennik.' }
    }
}

function Update-HTOperationSummary {
    param([Parameter(Mandatory)]$Window)
    $q = $Window.FindName('osFilter').Text.Trim()
    $withChecks = $Window.FindName('osChecks').IsChecked -eq $true
    $records = @(Get-HTOperationRecords -Object $q | Where-Object { $withChecks -or (Get-HTOperationKind $_) -ne 'Check' })
    $Window.Tag.Records = $records
    $Window.FindName('osText').Text = Format-HTOperationSummary -Records $records -Title $(if ($q) { "Wykonane czynności - $q" } else { '' })
    $checks = @($records | Where-Object { (Get-HTOperationKind $_) -eq 'Check' }).Count
    $Window.FindName('osCount').Text = "zmian: $($records.Count - $checks) • sprawdzeń: $checks"
}

function Show-HTOperationSummaryDialog {
    # Tekst do zgłoszenia z operacji wykonanych w tej sesji (filtr po obiekcie)
    param([string]$Object = '')
    $w = New-HTDialog -Title 'Podsumowanie do zgłoszenia' -Subtitle 'Co zostało sprawdzone i zrobione w tej sesji programu - gotowy tekst do zgłoszenia (ticketu).' -Body $script:OperationSummaryXaml -Icon 'E8A5' -OkText 'Zamknij' -NoCancel -Width 760
    $copy = New-HTButton -Text 'Kopiuj' -Icon 'E8C8'
    $copy.Margin = '0,0,8,0'
    $copy.add_Click($script:OperationSummaryEvents.Copy)
    [void]$w.FindName('dlgExtra').Children.Add($copy)
    if (Get-HTTeamsWebhookUrl) {
        $teams = New-HTButton -Text 'Wyślij do Teams' -Icon 'E8F2'
        $teams.add_Click($script:OperationSummaryEvents.Teams)
        [void]$w.FindName('dlgExtra').Children.Add($teams)
    }
    $filter = $w.FindName('osFilter')
    $filter.Text = $Object
    $filter.add_TextChanged($script:OperationSummaryEvents.Filter)
    $w.FindName('osChecks').add_Checked($script:OperationSummaryEvents.Filter)
    $w.FindName('osChecks').add_Unchecked($script:OperationSummaryEvents.Filter)
    Update-HTOperationSummary -Window $w
    [void](Invoke-HTDialog $w)
}
#endregion

#region Dane do zgłoszenia problemu (wsparcie)
function Get-HTSupportSections {
    <#
        Dane do zgłoszenia problemu: program, system, moduły (wczytane i zainstalowane wersje), połączenia i wątki usług,
        ustawienia (bez sekretów), ostatnie błędy i ostrzeżenia, wyjątki PowerShell z miejscem wystąpienia, końcówka dziennika.
    #>
    $sections = [ordered]@{}
    $sections['Program'] = @(
        "Helpdesk Tools $($Global:AppVersion)"
        "Plik: $($Global:HTScriptPath)"
        "Raport: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) ($([System.TimeZoneInfo]::Local.Id))"
        "Konto programu (MFA): $(if ($Global:HTActiveAccount) { $Global:HTActiveAccount } else { 'podstawowe' })"
    )
    $admin = try { if (Get-Command -Name Test-HTIsAdministrator -ErrorAction Ignore) { Test-HTIsAdministrator } else { '?' } } catch { '?' }
    $sections['System'] = @(
        "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)), $PSHOME"
        ".NET $([System.Environment]::Version)"
        "$([System.Runtime.InteropServices.RuntimeInformation]::OSDescription) ($([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture))"
        "Kultura: $((Get-Culture).Name), interfejs: $((Get-UICulture).Name), administrator: $admin, wątek okna: $([System.Threading.Thread]::CurrentThread.GetApartmentState())"
        "PSModulePath: $($env:PSModulePath -replace [regex]::Escape([System.IO.Path]::PathSeparator), ' | ')"
    )
    $sections['Moduły'] = foreach ($name in 'Microsoft.Graph.Authentication', 'ExchangeOnlineManagement', 'PnP.PowerShell', 'ActiveDirectory', 'Pester') {
        $loaded = @(Get-Module -Name $name | ForEach-Object { "$($_.Version)" })
        $installed = @(Get-Module -ListAvailable -Name $name -ErrorAction SilentlyContinue | Sort-Object Version -Descending | ForEach-Object { "$($_.Version) ($($_.ModuleBase))" })
        "$($name): wczytany $(if ($loaded.Count) { $loaded -join ', ' } else { '-' }); zainstalowane: $(if ($installed.Count) { $installed -join '; ' } else { 'brak' })"
    }
    $worker = { param($s) try { if (Get-Command -Name Test-HTServiceWorker -ErrorAction Ignore) { if (Test-HTServiceWorker -Service $s) { 'działa' } else { 'nie działa' } } else { '-' } } catch { '?' } }
    $sections['Połączenia'] = @(
        "Microsoft 365 (Graph): $(if ($Global:ConnectedToGraphAPI) { 'połączono' } else { 'nie' })"
        "Exchange Online: $(if ($Global:ConnectedToExchange) { 'połączono' } else { 'nie' }); w osobnym wątku: $($Global:ExchangeInBackground -ne $false) (wątek: $(& $worker 'Exchange'))"
        "SharePoint (PnP): $(if ($Global:ConnectedToSharepointPnP) { 'połączono' } else { 'nie' }); w osobnym wątku: $($Global:SharePointInBackground -ne $false) (wątek: $(& $worker 'SharePoint'))"
        "Active Directory: $(if ($Global:IsModuleActiveDirectoryLoaded) { 'moduł wczytany' } else { 'nie' })"
        "Operacje w tle (Graph): $($Global:BackgroundQueries -ne $false)$(if ($script:Background -and $script:Background.Disabled) { ' - wyłączone w tej sesji (brak połączenia w wątku w tle)' })"
    )
    $sections['Ustawienia'] = foreach ($n in 'DebugLogging', 'ShowNotifications', 'ShowOnPremises', 'ShowSystemMailboxes', 'BackgroundQueries', 'ExchangeInBackground', 'SharePointInBackground', 'LoginTimeoutMinutes', 'AutoLockMinutes', 'NotifyLongOperationsSeconds', 'LogFileMaxSizeMB', 'ExportPath', 'LogDir', 'ConfigDir') {
        $v = Get-Variable -Name $n -Scope Global -ValueOnly -ErrorAction Ignore
        "$($n): $(if ($null -eq $v) { '-' } else { [string]$v })"
    }
    $selfTest = @(try { if (Get-Command -Name Get-HTSelfTestReport -ErrorAction Ignore) { Get-HTSelfTestReport } } catch { "Autotest: $($_.Exception.Message)" })
    if ($selfTest.Count) { $sections['Ostatni autotest (Organizacja > Diagnostyka)'] = $selfTest }
    $history = @(Get-HTLogHistory)
    $sections['Ostatnie błędy i ostrzeżenia (25)'] = @($history | Where-Object { $_.Type -in 'Error', 'Warn' } | Select-Object -Last 25 | ForEach-Object { Format-HTLogEntry -Entry $_ })
    $sections['Ostatnie wyjątki PowerShell (5)'] = foreach ($e in @($global:Error | Select-Object -First 5)) {
        if ($e -is [System.Management.Automation.ErrorRecord]) {
            $where = if ($e.InvocationInfo -and $e.InvocationInfo.ScriptName) { "$(Split-Path -Leaf $e.InvocationInfo.ScriptName):$($e.InvocationInfo.ScriptLineNumber)" } else { '' }
            $stack = @(([string]$e.ScriptStackTrace) -split "`r?`n" | Where-Object { $_ } | Select-Object -First 4) -join ' <- '
            "$($e.Exception.GetType().Name): $(Compress-HTErrorText -Text $e.Exception.Message -MaxLength 800)$(if ($where) { " [$where]" })$(if ($stack) { " | $stack" })"
        }
        else { "$($e.GetType().Name): $(Compress-HTErrorText -Text ([string]$e) -MaxLength 800)" }
    }
    $sections['Dziennik - ostatnie wpisy (80)'] = @($history | Select-Object -Last 80 | ForEach-Object { Format-HTLogEntry -Entry $_ })
    return $sections
}

$script:SupportDialogXaml = @'
<StackPanel>
  <TextBox x:Name="spText" Style="{StaticResource MultiText}" IsReadOnly="True" Height="400" TextWrapping="NoWrap" FontFamily="Consolas" FontSize="12"/>
  <TextBlock Foreground="#7B8496" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"
             Text="Wersja programu i modułów, system, połączenia, ustawienia, ostatnie błędy i dziennik - bez haseł, tokenów i adresów webhooków. Dziennik może zawierać nazwy kont i skrzynek: sprawdź tekst przed wysłaniem poza firmę."/>
</StackPanel>
'@

$script:SupportDialogEvents = @{
    Copy = {
        param($s, $e)
        $t = [System.Windows.Window]::GetWindow($s).FindName('spText').Text
        if ($t) { Set-HTClipboard $t; Show-HTToast 'Skopiowano dane do zgłoszenia problemu.' 'ok' }
    }
    Zip  = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        try {
            $path = Save-HTSupportPackage -Report $w.FindName('spText').Text
            Show-HTToast "Zapisano paczkę: $path" 'ok' 8
            Start-Process -FilePath 'explorer.exe' -ArgumentList "/select,`"$path`""
        }
        catch { Show-HTError -Text 'Nie zapisano paczki dla wsparcia.' -ErrorObject $_ }
    }
}

function Save-HTSupportPackage {
    # Paczka ZIP dla wsparcia: raport (tekst) i pliki dziennika z ostatnich 2 dni; folder eksportu. Zwraca ścieżkę.
    param([Parameter(Mandatory)][string]$Report)
    $dir = Get-HTExportDirectory
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $work = Join-Path ([System.IO.Path]::GetTempPath()) "HelpdeskTools_wsparcie_$stamp"
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        [System.IO.File]::WriteAllText((Join-Path $work 'Dane_do_zgloszenia.txt'), $Report, (New-Object System.Text.UTF8Encoding($true)))
        foreach ($f in @(Get-HTLogFiles | Where-Object { $_.Date -ge (Get-Date).Date.AddDays(-1) })) {
            # Dziennik z tego dnia może być otwarty do zapisu - kopia przez strumień z FileShare.ReadWrite
            $src = [System.IO.File]::Open($f.Path, 'Open', 'Read', 'ReadWrite')
            try { $dst = [System.IO.File]::Create((Join-Path $work $f.Name)); try { $src.CopyTo($dst) } finally { $dst.Dispose() } } finally { $src.Dispose() }
        }
        $zip = Join-Path $dir "HelpdeskTools_wsparcie_$stamp.zip"
        Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
        return $zip
    }
    finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

function Show-HTSupportDialog {
    # Dane do zgłoszenia problemu: tekst do skopiowania albo paczka ZIP z dziennikiem
    Set-HTBusy -Busy $true -Text 'Zbieranie danych do zgłoszenia…'
    try { $text = Format-HTSupportReport -Sections (Get-HTSupportSections) }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    $w = New-HTDialog -Title 'Dane do zgłoszenia problemu' -Subtitle 'Do wysłania wsparciu: wersje, system, moduły, połączenia, ostatnie błędy i dziennik.' -Body $script:SupportDialogXaml -Icon 'EBE8' -OkText 'Zamknij' -NoCancel -Width 900
    $copy = New-HTButton -Text 'Kopiuj' -Icon 'E8C8' -Primary
    $copy.Margin = '0,0,8,0'
    $copy.add_Click($script:SupportDialogEvents.Copy)
    [void]$w.FindName('dlgExtra').Children.Add($copy)
    $zip = New-HTButton -Text 'Zapisz paczkę ZIP (z dziennikiem)' -Icon 'E74E'
    $zip.add_Click($script:SupportDialogEvents.Zip)
    [void]$w.FindName('dlgExtra').Children.Add($zip)
    $w.FindName('spText').Text = $text
    [void](Invoke-HTDialog $w)
}
#endregion

#region Ponowne uruchomienie programu
function Restart-HTApplication {
    <#
        Uruchamia program ponownie w nowym procesie PowerShell (np. po konflikcie bibliotek między modułami)
        i zamyka bieżące okno. -Connect: usługa, z którą nowa sesja połączy się zaraz po starcie.
    #>
    param([ValidateSet('', 'Exchange', 'Graph', 'SharePoint')][string]$Connect = '')
    $scriptPath = $Global:HTScriptPath
    if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath)) { Show-HTWarning 'Nie można ustalić ścieżki programu - uruchom go ponownie ręcznie.'; return }
    $arguments = @('-NoProfile', '-STA', '-File', ('"{0}"' -f $scriptPath))
    if ($Connect) { $arguments += @('-Connect', $Connect) }
    Write-Log -Message "Ponowne uruchamianie programu$(if ($Connect) { " (połączenie: $Connect)" })…" -Type 'Info'
    Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $arguments
    $Global:HTRestarting = $true
    if ($script:UI.Window) { $script:UI.Window.Close() }
}
#endregion

#region Przegląd wszystkich sekcji (autotest interfejsu)
<#
    Tryb przechwytywania okien: Invoke-HTDialog nie pokazuje okna, tylko zapisuje tytuł, treść i ton (crit / warn / info)
    i odpowiada «Anuluj». Każde pytanie o zmianę (Confirm-HTChange, Show-HTConfirm), formularz i wybór z listy kończy się
    więc rezygnacją - przegląd niczego nie zmienia. Powiadomienia (toast) też są zapisywane zamiast pokazywane.
#>
function Start-HTDialogCapture { $script:UI.DialogCapture = New-Object System.Collections.Generic.List[object] }

function Stop-HTDialogCapture {
    $captured = if ($null -ne $script:UI.DialogCapture) { $script:UI.DialogCapture.ToArray() } else { @() }
    $script:UI.DialogCapture = $null
    return $captured
}

function Test-HTDialogCapture { return ($null -ne $script:UI.DialogCapture) }

function Select-HTPanelSample {
    <#
        Przykładowy obiekt na liście po lewej do przeglądu modułów: -Prefer { param($o) } - obiekt preferowany (np. własne
        konto), inaczej pierwszy. Lista pusta - próba wczytania. Zwraca opis wybranego obiektu albo $null (brak obiektów).
        Zaznaczenie użytkownika (pola wyboru) jest zapamiętywane w -State i przywracane przez Restore-HTPanelSelection.
    #>
    param([Parameter(Mandatory)][hashtable]$Panel, [scriptblock]$Prefer = $null, [hashtable]$State = @{})
    $empty = if ($Panel.IsTree) { $Panel.pTree.Items.Count -eq 0 } else { $Panel.Table.Rows.Count -eq 0 }
    if ($empty -and $Panel.Loader -and (-not $Panel.Service -or (Test-HTConnection -Service $Panel.Service))) { Invoke-HTPanelLoad -Panel $Panel -Quiet }
    if ($Panel.IsTree) {
        $items = @($Panel.pTree.Items | Where-Object { $_ -is [System.Windows.Controls.TreeViewItem] -and $_.Tag -and $_.Tag -isnot [string] })
        if (-not $items.Count) { return $null }
        $pick = $null
        if ($Prefer) { $pick = @($items | Where-Object { try { & $Prefer $_.Tag } catch { $false } })[0] }
        if (-not $pick) { $pick = $items[0] }
        $State[$Panel.Key] = @{ Tree = $Panel.pTree.SelectedItem }
        $pick.IsSelected = $true
        return [string]$pick.Tag.Title
    }
    if ($Panel.Table.Rows.Count -eq 0) { return $null }
    if (-not $State.ContainsKey($Panel.Key)) { $State[$Panel.Key] = @{ Sel = @($Panel.Table.Select('Sel = true') | ForEach-Object { [string]$_['Key'] }) } }
    $key = $null
    if ($Prefer) { foreach ($k in @($Panel.Objects.Keys)) { if ((& { try { & $Prefer $Panel.Objects[$k] } catch { $false } })) { $key = [string]$k; break } } }
    if (-not $key) { $key = [string]$Panel.Table.Rows[0]['Key'] }
    foreach ($r in $Panel.Table.Rows) { $r['Sel'] = ([string]$r['Key'] -eq $key) }
    $row = @($Panel.Table.Select("Key = '$($key.Replace("'", "''"))'"))[0]
    return $(if ($row) { [string]$row['Title'] } else { $key })
}

function Restore-HTPanelSelection {
    # Przywrócenie zaznaczenia list sprzed przeglądu modułów
    param([hashtable]$State = @{})
    foreach ($k in @($State.Keys)) {
        $p = $script:UI.Panels[$k]
        if (-not $p) { continue }
        if ($p.IsTree) { if ($State[$k].Tree) { try { $State[$k].Tree.IsSelected = $true } catch { Write-Verbose $_ } }; continue }
        $sel = @($State[$k].Sel)
        foreach ($r in $p.Table.Rows) { $r['Sel'] = ($sel -contains [string]$r['Key']) }
    }
}

function Invoke-HTModuleSweep {
    <#
        Przegląd modułów: dla każdego modułu wybranych przestrzeni - otwarcie (zbudowanie), przykładowy obiekt na liście po
        lewej (-Preferences: klucz listy -> { param($o) } wybór obiektu, np. własne konto) i główny przycisk odczytu
        (niebieski, F5 - zawsze bez zmian). Okna są przechwytywane (Start-HTDialogCapture), więc nic się nie zmienia.
        Wynik dla modułu: OK (z liczbą wyników), Uwaga (komunikat - np. moduł wymaga danych), Błąd (wyjątek, błąd w dzienniku,
        wiersz «Błąd» w wynikach) albo Pominięto (brak połączenia, pusta lista, brak przycisku odczytu, brak dostępu).
        -OnResult { param($row) }, -OnStart { param($definition, $index, $total) }, -ShouldStop { }.
    #>
    param(
        [string[]]$Workspaces = @(),
        [string[]]$ExcludeKeys = @(),
        [hashtable]$Preferences = @{},
        [scriptblock]$OnStart = $null,
        [scriptblock]$OnResult = $null,
        [scriptblock]$ShouldStop = $null
    )
    $defs = @($script:UI.ModuleDefs | Where-Object { (-not $Workspaces.Count -or $Workspaces -contains $_.Workspace) -and $ExcludeKeys -notcontains $_.Key })
    $returnTo = if ($script:UI.ActiveModule) { $script:UI.ActiveModule.Key } else { '' }
    $selection = @{}
    $samples = @{}
    if (-not $script:UI.SweepSink) {
        Register-HTLogSink -ScriptBlock { param($entry) if ($null -ne $script:UI.SweepLog -and $entry.Type -eq 'Error') { $script:UI.SweepLog.Add([string]$entry.Message) } }
        $script:UI.SweepSink = $true
    }
    $results = New-Object System.Collections.Generic.List[object]
    $index = 0
    try {
        foreach ($d in $defs) {
            $index++
            if ($ShouldStop -and (& $ShouldStop)) { break }
            if ($OnStart) { & $OnStart $d $index $defs.Count }
            $ws = $script:UI.Workspaces[$d.Workspace]
            $service = if ($d.Service) { $d.Service } elseif ($ws) { $ws.Service } else { '' }
            $status = 'OK'
            $details = ''
            $sample = ''
            $started = Get-Date
            $m = $null
            if (-not (Test-HTModuleAllowed $d.Key)) { $status = 'Pominięto'; $details = 'Brak dostępu dla konta programu (MFA)' }
            elseif ($service -and -not (Test-HTConnection -Service $service)) { $status = 'Pominięto'; $details = "Brak połączenia: $service" }
            else {
                $script:UI.SweepLog = New-Object System.Collections.Generic.List[string]
                Start-HTDialogCapture
                try {
                    if ($ws -and $ws.Panel) {
                        $panel = $script:UI.Panels[$ws.Panel]
                        if (-not $samples.ContainsKey($ws.Panel)) { $samples[$ws.Panel] = if ($panel) { Select-HTPanelSample -Panel $panel -Prefer $Preferences[$ws.Panel] -State $selection } else { $null } }
                        $sample = [string]$samples[$ws.Panel]
                    }
                    Show-HTModule -Key $d.Key
                    $m = $script:UI.Modules[$d.Key]
                    if ($ws -and $ws.Panel -and -not $sample) { $status = 'Pominięto'; $details = 'Lista obiektów po lewej jest pusta' }
                    elseif (-not $m -or -not $m.PrimaryButton) { $status = 'Pominięto'; $details = 'Moduł bez przycisku odczytu (tylko tworzenie / zmiany - testy zapisu)' }
                    else {
                        $rowsBefore = if ($m.Table) { $m.Table.Rows.Count } else { 0 }
                        Invoke-HTModulePrimary -Module $m
                        Update-HTUi
                        $rows = if ($m.Table) { $m.Table.Rows.Count } else { 0 }
                        $errorRows = @()
                        if ($m.Table -and $m.Table.Columns.Contains('Status')) {
                            $errorRows = @($m.Table.Rows | Where-Object { [string]$_['Status'] -like 'Błąd*' } | ForEach-Object { if ($m.Table.Columns.Contains('Szczegóły')) { [string]$_['Szczegóły'] } else { 'wiersz z błędem' } })
                        }
                        $details = "wyników: $rows"
                        if ($errorRows.Count) { $status = 'Błąd'; $details = "wiersze z błędem: $($errorRows.Count) - $(@($errorRows | Select-Object -First 2) -join ' | ')" }
                    }
                }
                catch { $status = 'Błąd'; $details = $_.Exception.Message }
                finally {
                    $dialogs = @(Stop-HTDialogCapture)
                    $logErrors = @($script:UI.SweepLog)
                    $script:UI.SweepLog = $null
                }
                $crit = @($dialogs | Where-Object { $_.Tone -eq 'crit' })
                $warn = @($dialogs | Where-Object { $_.Tone -eq 'warn' })
                $other = @($dialogs | Where-Object { $_.Tone -notin 'crit', 'warn' })
                if ($status -ne 'Błąd' -and ($crit.Count -or $logErrors.Count)) {
                    $status = 'Błąd'
                    $details = (@(@($crit | ForEach-Object { "$($_.Title): $($_.Text)" }) + @($logErrors) | Select-Object -First 2) -join ' | ')
                }
                elseif ($status -eq 'OK' -and $warn.Count) { $status = 'Uwaga'; $details = "$details; komunikat: $(@($warn | Select-Object -First 1 | ForEach-Object { "$($_.Title): $($_.Text)" }))" }
                elseif ($status -eq 'OK' -and $other.Count) { $details = "$details; okno: $(@($other | Select-Object -First 1 | ForEach-Object { $_.Title }))" }
            }
            if (Get-Command -Name Compress-HTErrorText -ErrorAction Ignore) { $details = Compress-HTErrorText -Text $details -MaxLength 600 }
            $row = [PSCustomObject][ordered]@{
                Test       = "$(if ($ws) { $ws.Title } else { $d.Workspace }) > $($d.Title)"
                Usługa     = $(if ($service) { $service } else { 'bez usługi' })
                Rodzaj     = 'odczyt (przegląd modułu)'
                Obszar     = $d.Category
                Status     = $status
                'Czas (s)' = [Math]::Round(((Get-Date) - $started).TotalSeconds, 1)
                Szczegóły  = $(if ($sample) { "obiekt: $sample; $details" } else { $details })
                Klucz      = $d.Key
                __flag     = $(switch ($status) { 'Błąd' { 'crit' } 'Uwaga' { 'warn' } 'Pominięto' { 'muted' } default { '' } })
            }
            $results.Add($row)
            if ($OnResult) { & $OnResult $row }
        }
    }
    finally {
        if (Test-HTDialogCapture) { [void](Stop-HTDialogCapture) }
        $script:UI.SweepLog = $null
        Restore-HTPanelSelection -State $selection
        if ($returnTo) { try { Show-HTModule -Key $returnTo } catch { Write-Verbose $_ } }
    }
    return $results.ToArray()
}
#endregion
